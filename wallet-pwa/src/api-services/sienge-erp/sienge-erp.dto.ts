import { ERP_TYPES, WALLET_PAYMENT_METHODS, WALLET_PAYMENTS_STATUS } from '@prisma/client';
import { z } from 'zod';

export enum CREATE_ERP_BILL_STATUS {
  INACTIVE = 'Inactive',
  PROCESSING = 'Processing',
  SUCCESS = 'Success',
  FAILED = 'Failed',
}

export type SiengeCreateErpBillStatusRawResponse = {
  operationStatus?: string;
};

export const SIENGE_OPERATION_STATUS_MAP: Record<string, CREATE_ERP_BILL_STATUS> = {
  PROCESSING: CREATE_ERP_BILL_STATUS.PROCESSING,
  SUCCESS: CREATE_ERP_BILL_STATUS.SUCCESS,
  FAILED: CREATE_ERP_BILL_STATUS.FAILED,
  INACTIVE: CREATE_ERP_BILL_STATUS.INACTIVE,
};

export const createErpBillRequestDtoSchema = z.object({
  documentType: z.string().min(1),
  documentNumber: z.string().min(1),
  issuedDate: z.string().min(1),
  paymentTypeId: z.number().int(),
});

export type CreateErpBillRequestDto = z.infer<typeof createErpBillRequestDtoSchema>;

export const createErpBillResponseDtoSchema = z.object({
  success: z.boolean(),
  message: z.string().optional(),
});

export type CreateErpBillResponseDto = z.infer<typeof createErpBillResponseDtoSchema>;

export const createErpBillStatusQueryDtoSchema = z.object({
  documentNumber: z.string().min(1),
  paymentId: z.string().uuid(),
});

export type CreateErpBillStatusQueryDto = z.infer<typeof createErpBillStatusQueryDtoSchema>;

export const createErpBillStatusResponseSchema = z.object({
  operationStatus: z.nativeEnum(CREATE_ERP_BILL_STATUS),
});

export type CreateErpBillStatusResponse = z.infer<typeof createErpBillStatusResponseSchema>;

export const erpBillReferenceSchema = z.object({
  billId: z.string(),
  documentNumber: z.string().nullable(),
  documentType: z.string().nullable(),
  installmentNumber: z.number().nullable(),
  totalInstallments: z.number().nullable(),
  dueDate: z.string().nullable(),
  isAuthorized: z.boolean().nullable(),
  hasBeenAuthorized: z.boolean().nullable(),
});

export type ErpBillReference = z.infer<typeof erpBillReferenceSchema>;

export const getErpBillResponseSchema = z.object({
  bill: erpBillReferenceSchema.nullable(),
});

export type GetErpBillResponse = z.infer<typeof getErpBillResponseSchema>;

export const getErpBillQueryDtoSchema = z.object({
  paymentId: z.string().uuid(),
});

export type GetErpBillQueryDto = z.infer<typeof getErpBillQueryDtoSchema>;

export const getSiengePaymentTypesQueryDtoSchema = z.object({
  paymentMethod: z.nativeEnum(WALLET_PAYMENT_METHODS).optional(),
});

export type GetSiengePaymentTypesQueryDto = z.infer<typeof getSiengePaymentTypesQueryDtoSchema>;

export type SiengeDocumentType = {
  id: string;
  code: string;
  name?: string | null;
};

export type SiengePaymentType = {
  id: string;
  erpId: number;
  name: string;
  bankOperationId: number;
  defaultPaymentTypeFor: string;
};

export type SiengePaymentTypeOption = SiengePaymentType & {
  isDefault: boolean;
  isSuggested: boolean;
};

export type WalletPaymentErpLookupParams = {
  paymentId: string;
  walletId: string;
  customerId: string;
};

export type WalletPaymentAllocationLine = {
  projectId: string | null;
  costCenterId: string | null;
  managerialAccountId: string | null;
  allocation: number;
};

export type ResolvedWalletPaymentErp = {
  packageId: string | null;
  erp: ERP_TYPES | null;
  status: WALLET_PAYMENTS_STATUS;
  billId: string | null;
  paymentDate: string | null;
  allocations: WalletPaymentAllocationLine[];
};

export type PostCreateErpBillParams = {
  packageId: string;
  customerId: string;
  documentType: string;
  documentNumber: string;
  issuedDate: string;
  paymentTypeId: number;
};

export type GetErpBillStatusParams = {
  customerId: string;
  documentNumber: string;
};
