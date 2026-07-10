'use client';

import { ERP_TYPES, WALLET_PAYMENT_METHODS } from '@prisma/client';

import { ErpBillReferenceSection } from '@/modules/transactions/erp-bill/ErpBillReferenceSection';
import { ErpBillSection } from '@/modules/transactions/erp-bill/ErpBillSection';

import { AllocationSection } from './AllocationSection';
import { DescriptionSection } from './DescriptionSection';

type Props = {
  canEdit: boolean;
  customerErp?: ERP_TYPES | null;
  hasExistingBill?: boolean;
  initialDescription: string | null | undefined;
  packageId: string | undefined;
  paymentAmountCents: number;
  paymentConfirmed?: boolean;
  paymentDate?: Date | string | null;
  paymentId: string;
  paymentMethod?: WALLET_PAYMENT_METHODS;
  walletId: string;
};

export function PaymentInfoForm({
  canEdit,
  customerErp,
  hasExistingBill = false,
  initialDescription,
  packageId,
  paymentAmountCents,
  paymentConfirmed = false,
  paymentDate,
  paymentId,
  paymentMethod,
  walletId,
}: Props) {
  return (
    <div className="space-y-6">
      <DescriptionSection
        canEdit={canEdit}
        initialDescription={initialDescription}
        paymentId={paymentId}
        walletId={walletId}
      />

      <AllocationSection
        canEdit={canEdit}
        packageId={packageId}
        paymentAmountCents={paymentAmountCents}
        paymentId={paymentId}
        walletId={walletId}
      />

      <ErpBillReferenceSection
        customerErp={customerErp}
        paymentId={paymentId}
        walletId={walletId}
      />

      <ErpBillSection
        canEdit={canEdit}
        customerErp={customerErp}
        hasExistingBill={hasExistingBill}
        packageId={packageId}
        paymentConfirmed={paymentConfirmed}
        paymentDate={paymentDate}
        paymentId={paymentId}
        paymentMethod={paymentMethod}
        walletId={walletId}
      />
    </div>
  );
}
