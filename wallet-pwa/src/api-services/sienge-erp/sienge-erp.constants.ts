import { WALLET_PAYMENT_METHODS } from '@prisma/client';

export const SIENGE_REQUEST_TIMEOUT_MS = 10000;

export const DEFAULT_ERP_ERROR_MESSAGE = 'Não foi possível concluir a operação no Sienge.';

export const ALLOCATION_TOTAL_TOLERANCE = 0.01;

export const WALLET_METHOD_TO_SIENGE_KEY: Record<WALLET_PAYMENT_METHODS, string> = {
  [WALLET_PAYMENT_METHODS.KEY]: 'PIX',
  [WALLET_PAYMENT_METHODS.QR_CODE]: 'PIX',
  [WALLET_PAYMENT_METHODS.BARCODE]: 'BANKSLIP',
};

export const BANK_OPERATION_IDS_BY_METHOD: Record<string, number[]> = {
  PIX: [100, 101, 35],
  TED: [1, 2, 3, 7, 10, 16, 18, 37],
  BANKSLIP: [30, 31],
  BARCODE: [33, 91, 99],
};
