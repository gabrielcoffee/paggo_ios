import { PACKAGE_STATUS, PAYMENT_METHODS } from '@prisma/client';

export type PackageDuplicatedType = {
  amount: number;
  paymentDate: Date | null;
  paymentMethod: PAYMENT_METHODS;
  receiverName: string;
  payerName: string | null;
  status: PACKAGE_STATUS;
  requestName: string | undefined;
  requestDate: Date;
};
