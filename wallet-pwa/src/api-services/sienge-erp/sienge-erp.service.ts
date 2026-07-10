import { ERP_TYPES, WALLET_PAYMENT_METHODS, WALLET_PAYMENTS_STATUS } from '@prisma/client';
import axios, { AxiosInstance, HttpStatusCode } from 'axios';
import { DateTime } from 'luxon';

import { getWalletPaymentErpData } from '@paggo/services/services';

import {
  ALLOCATION_TOTAL_TOLERANCE,
  BANK_OPERATION_IDS_BY_METHOD,
  DEFAULT_ERP_ERROR_MESSAGE,
  SIENGE_REQUEST_TIMEOUT_MS,
  WALLET_METHOD_TO_SIENGE_KEY,
} from './sienge-erp.constants';
import {
  CREATE_ERP_BILL_STATUS,
  CreateErpBillRequestDto,
  CreateErpBillStatusResponse,
  ErpBillReference,
  GetErpBillStatusParams,
  PostCreateErpBillParams,
  ResolvedWalletPaymentErp,
  SIENGE_OPERATION_STATUS_MAP,
  SiengeCreateErpBillStatusRawResponse,
  SiengeDocumentType,
  SiengePaymentType,
  SiengePaymentTypeOption,
  WalletPaymentErpLookupParams,
} from './sienge-erp.dto';
import {
  ErpBillAllocationIncompleteError,
  ErpBillAlreadyExistsError,
  ErpBillInvalidIssuedDateError,
  ErpBillMissingPackageError,
  ErpBillNotSiengeCustomerError,
  ErpBillPaymentNotConfirmedError,
  ErpBillPaymentNotFoundError,
  SiengeErpRequestError,
} from './sienge-erp.exception';

const SIENGE_BASE_URL = process.env.SIENGE_BASE_URL;
const SIENGE_API_KEY = process.env.SIENGE_API_KEY;

let siengeApiInstance: AxiosInstance | undefined;

function getSiengeApi(): AxiosInstance {
  if (siengeApiInstance) return siengeApiInstance;

  if (!SIENGE_BASE_URL || !SIENGE_API_KEY) {
    throw new Error('SIENGE_BASE_URL and SIENGE_API_KEY must be configured.');
  }

  siengeApiInstance = axios.create({
    baseURL: SIENGE_BASE_URL,
    headers: {
      'Content-Type': 'application/json',
      'api-key': SIENGE_API_KEY,
    },
    timeout: SIENGE_REQUEST_TIMEOUT_MS,
  });

  return siengeApiInstance;
}

const getStringField = (data: unknown, key: string): string | undefined => {
  if (!data || typeof data !== 'object') return undefined;

  const value = (data as Record<string, unknown>)[key];

  return typeof value === 'string' && value.trim() ? value : undefined;
};

const getNestedErrorMessage = (data: unknown): string | undefined => {
  if (!data || typeof data !== 'object') return undefined;

  const error = (data as Record<string, unknown>).error;
  if (!error || typeof error !== 'object') return undefined;

  const message = (error as Record<string, unknown>).message;
  if (Array.isArray(message)) {
    return message.filter((item): item is string => typeof item === 'string').join(', ');
  }

  return typeof message === 'string' && message.trim() ? message : undefined;
};

export function getSiengeErrorMessage(error: unknown): string {
  const data = axios.isAxiosError(error) ? error.response?.data : error;
  const responseMessage =
    getStringField(data, 'clientMessage') ??
    getStringField(data, 'developerMessage') ??
    getStringField(data, 'message') ??
    getNestedErrorMessage(data);

  if (responseMessage) return responseMessage;

  if (axios.isAxiosError(error)) {
    return error.message || DEFAULT_ERP_ERROR_MESSAGE;
  }

  return error instanceof Error && error.message ? error.message : DEFAULT_ERP_ERROR_MESSAGE;
}

function toSiengeErpRequestError(error: unknown): SiengeErpRequestError {
  const statusCode = axios.isAxiosError(error)
    ? error.response?.status ?? HttpStatusCode.BadGateway
    : HttpStatusCode.InternalServerError;

  return new SiengeErpRequestError(statusCode, getSiengeErrorMessage(error));
}

export async function resolveWalletPaymentForErpBill(
  params: WalletPaymentErpLookupParams
): Promise<ResolvedWalletPaymentErp | null> {
  const walletPayment = await getWalletPaymentErpData(
    params.walletId,
    params.paymentId,
    params.customerId
  );

  if (!walletPayment) return null;

  const firstPackage = walletPayment.deliveryDocument?.deliveryDocumentPackages?.[0];
  const paymentDate = walletPayment.paidAt ?? walletPayment.createdAt;

  return {
    packageId: walletPayment.packageId ?? firstPackage?.packageId ?? null,
    erp: walletPayment.customer?.erp ?? null,
    status: walletPayment.status,
    paymentDate: paymentDate ? paymentDate.toISOString() : null,
    allocations: (firstPackage?.package?.allocations ?? []).map((a) => ({
      projectId: a.projectId ?? null,
      costCenterId: a.costCenterId ?? null,
      managerialAccountId: a.managerialAccountId ?? null,
      allocation: Number(a.allocation),
    })),
    billId: firstPackage?.package?.packageErp?.billId ?? null,
  };
}

export async function getWalletPaymentErpBill(
  params: WalletPaymentErpLookupParams
): Promise<ErpBillReference | null> {
  const walletPayment = await getWalletPaymentErpData(
    params.walletId,
    params.paymentId,
    params.customerId
  );

  if (!walletPayment) return null;

  const packageErp =
    walletPayment.deliveryDocument?.deliveryDocumentPackages?.[0]?.package?.packageErp;

  if (!packageErp?.billId) return null;

  return {
    billId: packageErp.billId,
    documentNumber: packageErp.documentNumber ?? null,
    documentType: packageErp.documentType ?? null,
    installmentNumber: packageErp.installmentNumber ?? null,
    totalInstallments: packageErp.totalInstallments ?? null,
    dueDate: packageErp.dueDate ? packageErp.dueDate.toISOString() : null,
    isAuthorized: packageErp.isAuthorized ?? null,
    hasBeenAuthorized: packageErp.hasBeenAuthorized ?? null,
  };
}

async function postCreateErpBill(params: PostCreateErpBillParams): Promise<void> {
  await getSiengeApi().post('/v1/platform/create-erp-bill', {
    packageIds: [params.packageId],
    customerId: params.customerId,
    documentType: params.documentType,
    documentNumber: params.documentNumber,
    issuedDate: params.issuedDate,
    paymentTypeId: params.paymentTypeId,
  });
}

function validateWalletPaymentForBillCreation(
  walletPayment: ResolvedWalletPaymentErp,
  issuedDate: string
): string {
  if (walletPayment.erp !== ERP_TYPES.SIENGE) {
    throw new ErpBillNotSiengeCustomerError();
  }

  if (walletPayment.status !== WALLET_PAYMENTS_STATUS.CONFIRMED) {
    throw new ErpBillPaymentNotConfirmedError();
  }

  if (walletPayment.billId) {
    throw new ErpBillAlreadyExistsError();
  }

  if (!walletPayment.packageId) {
    throw new ErpBillMissingPackageError();
  }

  const allocationComplete =
    walletPayment.allocations.length > 0 &&
    walletPayment.allocations.every(
      (a) => a.projectId && a.costCenterId && a.managerialAccountId
    ) &&
    Math.abs(walletPayment.allocations.reduce((sum, a) => sum + a.allocation, 0) - 100) <
      ALLOCATION_TOTAL_TOLERANCE;

  if (!allocationComplete) {
    throw new ErpBillAllocationIncompleteError();
  }

  if (walletPayment.paymentDate) {
    const parsedIssuedDate = DateTime.fromISO(issuedDate);
    const paymentLimit = DateTime.fromISO(walletPayment.paymentDate).endOf('day');
    if (!parsedIssuedDate.isValid || parsedIssuedDate > paymentLimit) {
      throw new ErpBillInvalidIssuedDateError();
    }
  }

  return walletPayment.packageId;
}

export async function createErpBillForWalletPayment(
  params: WalletPaymentErpLookupParams & { data: CreateErpBillRequestDto }
): Promise<void> {
  const walletPayment = await resolveWalletPaymentForErpBill({
    paymentId: params.paymentId,
    walletId: params.walletId,
    customerId: params.customerId,
  });

  if (!walletPayment) {
    throw new ErpBillPaymentNotFoundError();
  }

  const packageId = validateWalletPaymentForBillCreation(walletPayment, params.data.issuedDate);

  try {
    await postCreateErpBill({
      packageId,
      customerId: params.customerId,
      documentType: params.data.documentType,
      documentNumber: params.data.documentNumber,
      issuedDate: params.data.issuedDate,
      paymentTypeId: params.data.paymentTypeId,
    });
  } catch (error) {
    throw toSiengeErpRequestError(error);
  }
}

export async function getCreateErpBillStatus(
  params: GetErpBillStatusParams
): Promise<CreateErpBillStatusResponse> {
  try {
    const { data } = await getSiengeApi().get<SiengeCreateErpBillStatusRawResponse>(
      '/v1/platform/create-erp-bill/status',
      { params: { customerId: params.customerId, documentNumber: params.documentNumber } }
    );

    return {
      operationStatus:
        SIENGE_OPERATION_STATUS_MAP[data.operationStatus?.toUpperCase() ?? ''] ??
        CREATE_ERP_BILL_STATUS.INACTIVE,
    };
  } catch (error) {
    console.error('[sienge-erp] Failed to fetch ERP bill status from Sienge', error);
    throw toSiengeErpRequestError(error);
  }
}

export async function getSiengeDocumentTypes(customerId: string): Promise<SiengeDocumentType[]> {
  const { data } = await getSiengeApi().get<SiengeDocumentType[]>(
    `/v1/platform/customers/${customerId}/document-types`
  );

  return data;
}

async function getSiengePaymentTypes(
  customerId: string,
  paymentMethod?: string
): Promise<SiengePaymentType[]> {
  const params: Record<string, string> = {};
  if (paymentMethod) params.paymentMethod = paymentMethod;

  const { data } = await getSiengeApi().get<SiengePaymentType[]>(
    `/v1/platform/customers/${customerId}/payment-types`,
    { params }
  );

  return data;
}

export async function getSiengePaymentTypeOptions(
  customerId: string,
  walletPaymentMethod?: WALLET_PAYMENT_METHODS
): Promise<SiengePaymentTypeOption[]> {
  const methodKey = walletPaymentMethod
    ? WALLET_METHOD_TO_SIENGE_KEY[walletPaymentMethod]
    : undefined;

  const paymentTypes = await getSiengePaymentTypes(customerId, methodKey);
  const compatibleBankOps = methodKey ? BANK_OPERATION_IDS_BY_METHOD[methodKey] ?? [] : [];

  return paymentTypes
    .map((paymentType) => ({
      ...paymentType,
      isSuggested: compatibleBankOps.includes(paymentType.bankOperationId),
      isDefault: !!methodKey && paymentType.defaultPaymentTypeFor === methodKey,
    }))
    .sort((a, b) => {
      if (a.isSuggested !== b.isSuggested) return a.isSuggested ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
}
