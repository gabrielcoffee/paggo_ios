import { useMemo } from 'react';

import { ERP_TYPES, WALLET_PAYMENT_METHODS } from '@prisma/client';
import { toUpper } from 'lodash';
import { CircleArrowDownIcon, CircleArrowUpIcon, InfoIcon } from 'lucide-react';
import { DateTime } from 'luxon';

import { getBankNameFromISPB } from '@paggo/constants/src/bacen-institutions';
import { CELCOIN_BANK, PAGGO_LEGAL_NAME, PAGGO_TAX_ID } from '@paggo/constants/src/company';
import {
  capitalizeString,
  cnpjValid,
  formatNumberReal,
  formatToCPFOrCNPJ,
  padZero,
} from '@paggo/core-utils';
import { cn } from '@paggo/fend/utils';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import { useSession } from '@paggotech/next-auth/react';

import { AttachmentsSection } from '@/modules/transactions/payment-info/AttachmentsSection';
import { PaymentInfoForm } from '@/modules/transactions/payment-info/PaymentInfoForm';

type TransactionDetailProps = {
  transaction?: {
    id: string;
    date: string;
    amount: number;
    status: string;
    customerErp?: ERP_TYPES;
    hasErpBill?: boolean;
    method: WALLET_PAYMENT_METHODS;
    endToEndId?: string;
    digitableLine?: string;
    authenticationData?: string;
    dueDate?: Date;
    fineAmount?: number;
    discountAmount?: number;
    interestAmount?: number;
    assignor?: string;
    creditParty: {
      bankCode?: string;
      branch?: string;
      accountNumber?: string;
      receiverLegalName: string;
      receiverDocumentNumber: string;
    };
    debitParty: {
      accountNumber: string;
      receiverLegalName: string;
      receiverDocumentNumber: string;
    };
    description?: string | null;
    paymentId?: string;
    walletId?: string;
    packageId?: string;
    intentAuthorId?: string;
    paymentCreatedAt?: Date | string | null;
    attachments?: {
      id: string;
      name: string | null;
      url: string | null;
      createdAt: Date | string;
    }[];
  };
};

type TransactionDetailPartyProps = {
  className?: string;
  label: string;
  value?: string;
};

function TransactionDetailParty({ className, label, value }: TransactionDetailPartyProps) {
  return value ? (
    <div className={cn('mb-2 mt-4 flex w-full items-start justify-between gap-x-6', className)}>
      <SemanticTypography.Body size="big" color="gray-500" className="text-left">
        {label}
      </SemanticTypography.Body>

      <SemanticTypography.Body
        size="big"
        color="gray-500"
        className="flex whitespace-normal text-right"
      >
        {value}
      </SemanticTypography.Body>
    </div>
  ) : null;
}

export default function TransactionDetail({ transaction }: TransactionDetailProps) {
  const paymentSuccess = useMemo(() => transaction?.status === 'CONFIRMED', [transaction?.status]);

  const isPix = useMemo(
    () => transaction?.method === 'KEY' || transaction?.method === 'QR_CODE',
    [transaction?.method]
  );
  const isBarcode = useMemo(() => transaction?.method === 'BARCODE', [transaction?.method]);

  const title = useMemo(() => {
    if (paymentSuccess) {
      return isPix ? 'Pix enviado' : 'Pagamento efetuado';
    }

    return isPix ? 'Tentativa de pix falhou' : 'Tentativa de pagamento falhou';
  }, [isPix, paymentSuccess]);

  const { data: session } = useSession();
  const sessionUserId = (session?.user as { userId?: string } | undefined)?.userId;
  const canEditAllocation =
    !!transaction?.intentAuthorId &&
    !!sessionUserId &&
    transaction.intentAuthorId === sessionUserId;

  if (!transaction) return <></>;

  return (
    <div className="flex max-w-7xl px-4 sm:px-6 lg:px-8">
      <div className="flex w-full flex-col items-start justify-center">
        <SemanticTypography.Display size="small" className="mb-1 font-normal" color="white-pure">
          {title}
        </SemanticTypography.Display>

        <SemanticTypography.Overhead size="mid" color="gray-500">
          {toUpper(
            DateTime.fromISO(transaction.date).setLocale('pt-br').toFormat("dd LLL yyyy ' - ' TT")
          ).replace('.', '')}
        </SemanticTypography.Overhead>

        <TransactionDetailParty
          label="Valor"
          value={formatNumberReal(transaction.amount / 100)}
          className="mb-2 mt-4"
        />

        <TransactionDetailParty
          label="Tipo de pagamento"
          value={isPix ? 'Pix' : 'Código de barras'}
          className="mb-4 mt-2"
        />

        <div className="relative isolate">
          <div className="absolute inset-y-0 right-full -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
          <div className="absolute inset-y-0 left-0 -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
        </div>

        <div className="-ml-4 flex w-[calc(100%+32px)] items-center gap-4 bg-gray-800 px-4 pb-2 pt-4">
          <CircleArrowDownIcon className="text-white-pure h-5 w-5 shrink-0" />
          <SemanticTypography.Title size="big" color="white-pure">
            Dados do Recebedor
          </SemanticTypography.Title>
        </div>

        <TransactionDetailParty
          label="Nome"
          value={capitalizeString(transaction.creditParty.receiverLegalName)}
        />

        <TransactionDetailParty
          label={cnpjValid(transaction.creditParty.receiverDocumentNumber) ? 'CNPJ' : 'CPF'}
          value={formatToCPFOrCNPJ(transaction.creditParty.receiverDocumentNumber, {
            mask: 'cpf',
          })}
        />

        <TransactionDetailParty
          label="Instituição"
          value={
            transaction.creditParty.bankCode &&
            capitalizeString(getBankNameFromISPB(transaction.creditParty.bankCode) ?? '')
          }
        />

        {transaction.creditParty.branch && (
          <TransactionDetailParty
            label="Agência"
            value={padZero(transaction.creditParty.branch || '', 4)}
          />
        )}

        <TransactionDetailParty
          label="Conta"
          value={transaction.creditParty.accountNumber}
          className="mb-4"
        />

        <div className="relative isolate">
          <div className="absolute inset-y-0 right-full -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
          <div className="absolute inset-y-0 left-0 -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
        </div>

        <div className="-ml-4 flex w-[calc(100%+32px)] items-center gap-4 bg-gray-800 px-4 pb-2 pt-4">
          <CircleArrowUpIcon className="text-white-pure h-5 w-5 shrink-0" />
          <SemanticTypography.Title size="big" color="white-pure">
            Dados do Pagador
          </SemanticTypography.Title>
        </div>

        <TransactionDetailParty
          label="Nome"
          value={capitalizeString(transaction.debitParty.receiverLegalName)}
          className="truncate"
        />

        <TransactionDetailParty
          label={cnpjValid(transaction.debitParty.receiverDocumentNumber) ? 'CNPJ' : 'CPF'}
          value={formatToCPFOrCNPJ(transaction.debitParty.receiverDocumentNumber, {
            mask: 'cpf',
          })}
        />

        <TransactionDetailParty
          label="Instituição"
          value={capitalizeString(getBankNameFromISPB(CELCOIN_BANK.institution) ?? '')}
        />

        <TransactionDetailParty label="Agência" value={padZero(CELCOIN_BANK.branch || '', 4)} />

        <TransactionDetailParty
          label="Conta"
          value={transaction.debitParty.accountNumber}
          className="mb-4"
        />

        <div className="relative isolate">
          <div className="absolute inset-y-0 right-full -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
          <div className="absolute inset-y-0 left-0 -z-10 w-[calc(100vw-16px)] border-b border-gray-700 bg-gray-800" />
        </div>

        {isBarcode && (
          <>
            <div className="-ml-4 flex w-[calc(100%+32px)] items-center gap-4 bg-gray-800 px-4 pb-2 pt-4">
              <InfoIcon className="text-white-pure h-5 w-5 shrink-0" />
              <SemanticTypography.Title size="big" color="white-pure">
                Detalhes da Transação
              </SemanticTypography.Title>
            </div>

            <TransactionDetailParty label="Emissor" value={transaction.assignor} />

            <TransactionDetailParty
              label="Valor original"
              value={formatNumberReal((transaction.amount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Multa"
              value={formatNumberReal((transaction.fineAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Juros"
              value={formatNumberReal((transaction.interestAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Desconto"
              value={formatNumberReal((transaction.discountAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Data de vencimento"
              value={
                transaction?.dueDate &&
                DateTime.fromJSDate(new Date(transaction.dueDate)).toFormat('dd/MM/yyyy')
              }
              className="mb-4"
            />
          </>
        )}

        <div className="-ml-4 mb-4 flex w-[calc(100%+32px)] flex-col justify-start gap-2 bg-gray-800 px-4 py-6">
          {isPix && (
            <>
              {transaction.endToEndId && (
                <SemanticTypography.Title size="small" color="white-pure" className="text-start">
                  ID de transação: {transaction.endToEndId}
                </SemanticTypography.Title>
              )}
            </>
          )}

          {isBarcode && (
            <>
              {transaction.digitableLine && (
                <SemanticTypography.Title
                  size="small"
                  color="white-pure"
                  className="overflow-x-auto text-start"
                >
                  Linha digitável: {transaction.digitableLine}
                </SemanticTypography.Title>
              )}

              {transaction.authenticationData && (
                <SemanticTypography.Title
                  size="small"
                  color="white-pure"
                  className="overflow-x-auto text-start"
                >
                  Código de Autenticação: {transaction.authenticationData}
                </SemanticTypography.Title>
              )}
            </>
          )}

          <div className="flex flex-col">
            <SemanticTypography.Title size="small" color="white-pure" className="text-start">
              {PAGGO_LEGAL_NAME}
            </SemanticTypography.Title>

            <SemanticTypography.Title size="small" color="white-pure" className="text-start">
              CNPJ: {formatToCPFOrCNPJ(PAGGO_TAX_ID)}
            </SemanticTypography.Title>
          </div>
        </div>

        {transaction.paymentId && transaction.walletId && (
          <div className="flex w-full flex-col gap-6">
            <PaymentInfoForm
              canEdit={canEditAllocation}
              customerErp={transaction.customerErp}
              hasExistingBill={transaction.hasErpBill}
              initialDescription={transaction.description}
              packageId={transaction.packageId}
              paymentAmountCents={transaction.amount}
              paymentConfirmed={transaction.status === 'CONFIRMED'}
              paymentDate={transaction.paymentCreatedAt}
              paymentId={transaction.paymentId}
              paymentMethod={transaction.method}
              walletId={transaction.walletId}
            />

            <div className="border-t border-gray-700" />

            <AttachmentsSection
              attachments={transaction.attachments ?? []}
              canEdit={canEditAllocation}
              description={transaction.description}
              paymentId={transaction.paymentId}
              walletId={transaction.walletId}
            />
          </div>
        )}
      </div>
    </div>
  );
}
