'use client';

import { ERP_TYPES } from '@prisma/client';
import { CircleCheckBig } from 'lucide-react';
import { DateTime } from 'luxon';

import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import { Content } from '@paggo/ui/components/atoms/content';

import { useErpBillReference } from '@/hooks/erp/use-erp-bill';

type Props = {
  customerErp?: ERP_TYPES | null;
  paymentId: string;
  walletId: string;
};

type ReferenceRowProps = {
  label: string;
  value?: string | null;
};

function ReferenceRow({ label, value }: ReferenceRowProps) {
  if (!value) return null;

  return (
    <div className="flex items-start justify-between gap-x-6">
      <Content.Body size="big" value={label} />
      <Content.Body size="big" value={value} highlight />
    </div>
  );
}

export function ErpBillReferenceSection({ customerErp, paymentId, walletId }: Props) {
  const isSienge = customerErp === ERP_TYPES.SIENGE;
  const { bill } = useErpBillReference({ paymentId, walletId, enabled: isSienge });

  if (!isSienge || !bill) return null;

  const dueDate = bill.dueDate
    ? DateTime.fromISO(bill.dueDate).setLocale('pt-br').toFormat('dd/MM/yyyy')
    : null;

  const billReference = bill.installmentNumber
    ? `#${bill.billId}/${bill.installmentNumber}`
    : `#${bill.billId}`;

  const authorizationLabel = bill.isAuthorized ? 'Autorizado' : 'Aguardando autorização';

  return (
    <div className="space-y-4 border-t border-gray-700 pt-6">
      <div className="flex items-center gap-3">
        <CircleCheckBig className="h-5 w-5 shrink-0 text-green-500" />
        <Content.Body size="mid" value="Título no Sienge" highlight />
        <Badge semantic="success" label="Título criado" />
      </div>

      <div className="space-y-2">
        <ReferenceRow label="Título/Parcela" value={billReference} />
        <ReferenceRow label="Tipo de documento" value={bill.documentType} />
        <ReferenceRow label="Número do documento" value={bill.documentNumber} />
        <ReferenceRow label="Vencimento" value={dueDate} />
        <ReferenceRow label="Status" value={authorizationLabel} />
      </div>
    </div>
  );
}
