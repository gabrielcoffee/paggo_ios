import { Fragment, useMemo } from 'react';

import { groupBy, map, sortBy, toLower, toUpper } from 'lodash';
import { ChevronRightIcon, PaperclipIcon, CheckCheck } from 'lucide-react';
import { DateTime } from 'luxon';

import { capitalizeString, formatToCPFOrCNPJ } from '@paggo/core-utils';
import { cn } from '@paggo/fend/utils';
import { Barcode as BarcodeIcon } from '@paggo/icons/Barcode';
import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { Pix as PixIcon } from '@paggo/icons/Pix';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import WalletSelection from '@/components/wallet-selection/WalletSelection';
import { shouldFlagAllocationPending } from '@/modules/transactions/allocation/helpers';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

function EmptyIcon() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="60"
      height="60"
      version="1.1"
      viewBox="0 0 32 32"
      xmlSpace="preserve"
    >
      <path
        fill="none"
        stroke="#fff"
        strokeLinejoin="round"
        strokeMiterlimit="10"
        strokeWidth="2"
        d="M17 5H5a2 2 0 00-2 2v22a2 2 0 002 2h18a2 2 0 002-2V18"
      ></path>
      <path
        fill="none"
        stroke="#fff"
        strokeLinejoin="round"
        strokeMiterlimit="10"
        strokeWidth="2"
        d="M9 14H3v8h6a4 4 0 004-4v0a4 4 0 00-4-4z"
      ></path>
      <circle cx="9" cy="18" r="1"></circle>
      <path
        fill="none"
        stroke="#fff"
        strokeLinejoin="round"
        strokeMiterlimit="10"
        strokeWidth="2"
        d="M25 16L25 1"
      ></path>
      <path
        fill="none"
        stroke="#fff"
        strokeLinejoin="round"
        strokeMiterlimit="10"
        strokeWidth="2"
        d="M31 7L25 1 19 7"
      ></path>
    </svg>
  );
}

function EmptyState() {
  return (
    <div className="my-6 flex flex-col items-center justify-center gap-4 px-4 text-center">
      <EmptyIcon />
      <SemanticTypography.Caption color="white-pure" size="big" highlight>
        Humm, parece que você ainda não fez nenhum pagamento.
      </SemanticTypography.Caption>

      <SemanticTypography.Caption size="big" color="gray-500">
        Assim que fizer algum pagamento, ele irá aparecer aqui.
      </SemanticTypography.Caption>
    </div>
  );
}

export default function TransactionsContent() {
  const { currentWallet } = useWalletStore((state) => state);
  const { payments } = useWalletPaymentService({ fetch: true, walletId: currentWallet?.id });
  const { data, isLoading } = payments;

  const { navigateTo } = useNavigationStore();

  const transactions = useMemo(() => {
    if (!data || !data?.length) return [];

    const dateFormat = 'yyyy-MM-dd';
    const fullDateFormat = 'dd/MM/yyyy hh:mm:ss.SSS';

    const sorted = sortBy(
      data,
      (i) => -DateTime.fromJSDate(new Date(i?.createdAt)).toFormat(fullDateFormat)
    );

    const grouped = groupBy(sorted, (i) =>
      DateTime.fromJSDate(new Date(i?.createdAt)).toFormat(dateFormat)
    );

    const mapped = map(grouped, (group, date) => {
      return {
        dateTime: date,
        transactions: sortBy(group, (g) => -DateTime.fromJSDate(new Date(g?.createdAt))).map(
          (i) => ({
            id: i.id,
            amount: i.amount,
            time: DateTime.fromJSDate(new Date(i.createdAt))
              .setLocale('pt-br')
              .toLocaleString(DateTime.TIME_24_SIMPLE),
            status: i.status,
            released: i.released,
            method: i.intent.paymentMethod,
            receiverLegalName: i.receiverName,
            receiverDocumentNumber: formatToCPFOrCNPJ(i.receiverTaxId, { mask: 'cpf' }),
            hasAttachments: !!i.attachments?.length,
            erpBillId:
              i?.deliveryDocument?.deliveryDocumentPackages?.[0]?.package?.packageErp?.billId ??
              null,
            erpBillInstallmentNumber:
              i?.deliveryDocument?.deliveryDocumentPackages?.[0]?.package?.packageErp
                ?.installmentNumber ?? null,
            createdAtIso: i?.createdAt,
            package: i?.deliveryDocument?.deliveryDocumentPackages?.[0]?.package ?? null,
          })
        ),
      };
    });

    return mapped;
  }, [data]);

  return (
    <div className="flex flex-col overflow-x-hidden">
      <div className="my-4 gap-2 px-4 py-2">
        <div className="flex flex-col pb-2">
          <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
            Extrato
          </SemanticTypography.Display>
        </div>

        <WalletSelection fetchDeleted />
      </div>

      <div className="mt-6 flex h-full flex-col overflow-y-auto overflow-x-hidden">
        <div
          className={cn(
            'h-full flex-grow overflow-y-auto overflow-x-hidden pb-14 sm:px-6 lg:px-8',
            isLoading && 'h-screen'
          )}
        >
          {isLoading && (
            <div className="flex items-center justify-center">
              <LoadingCircle className="text-white-pure h-8 w-8" />
            </div>
          )}

          {!isLoading && (
            <>
              {data?.length ? (
                <table className="relative h-full w-full overflow-y-auto overflow-x-hidden text-left">
                  {transactions.map((day) => (
                    <Fragment key={day.dateTime}>
                      <thead>
                        <tr>
                          <th className="relative top-0 z-10 px-4 py-3">
                            <SemanticTypography.Title size="small" color="gray-500">
                              <time dateTime={day.dateTime}>
                                {-DateTime.fromISO(day.dateTime).diffNow().as('day') < 2
                                  ? capitalizeString(
                                      DateTime.fromISO(day.dateTime).toRelativeCalendar({
                                        locale: 'pt-br',
                                      })
                                    )
                                  : `${toLower(
                                      DateTime.fromISO(day.dateTime)
                                        .setLocale('pt-br')
                                        .toFormat('cccc')
                                        .split('-')[0]
                                    )}, ${toLower(
                                      DateTime.fromISO(day.dateTime)
                                        .setLocale('pt-br')
                                        .toFormat("dd 'de' MMMM")
                                    )}`}
                              </time>
                            </SemanticTypography.Title>

                            <div className="absolute inset-y-0 left-0 -z-10 w-full border-b border-gray-700 bg-gray-800" />
                          </th>
                        </tr>
                      </thead>

                      <tbody className="scrollbar-hide flex flex-col px-4">
                        {day.transactions.map((transaction) => {
                          const hasAttachment = transaction.hasAttachments;
                          const isPix =
                            transaction.method === 'KEY' || transaction.method === 'QR_CODE';

                          const allocationPending = shouldFlagAllocationPending(
                            transaction.package,
                            transaction.createdAtIso
                          );

                          const showErpBillBadge = !!transaction.erpBillId;
                          const erpBillBadgeLabel = transaction.erpBillInstallmentNumber
                            ? `Título #${transaction.erpBillId}/${transaction.erpBillInstallmentNumber}`
                            : `Título #${transaction.erpBillId}`;
                          const showPendingBadge =
                            !showErpBillBadge && (!hasAttachment || allocationPending);

                          return (
                            <tr key={transaction.id}>
                              <button
                                className="bg-gray-25 flex w-full"
                                key={transaction.id}
                                onClick={() =>
                                  navigateTo({
                                    screen: NavigationItem.TRANSACTIONS,
                                    id: String(transaction.id),
                                  })
                                }
                              >
                                <td className="relative flex w-full items-center py-5">
                                  <div className="flex gap-x-6">
                                    <div className="my-auto flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-800">
                                      {isPix ? (
                                        <PixIcon className="h-5 w-5 shrink-0 text-gray-500" />
                                      ) : (
                                        <BarcodeIcon className="h-5 w-5 shrink-0 text-gray-500" />
                                      )}
                                    </div>

                                    <div className="flex w-full flex-col">
                                      <SemanticTypography.Label
                                        color="gray-500"
                                        size="mid"
                                        className="line-clamp-1 text-ellipsis text-left"
                                      >
                                        {toUpper(transaction.receiverLegalName)}
                                      </SemanticTypography.Label>

                                      <SemanticTypography.Caption
                                        color="gray-500"
                                        size="mid"
                                        className="mt-1"
                                      >
                                        {formatToCPFOrCNPJ(transaction.receiverDocumentNumber, {
                                          mask: 'cpf',
                                        })}
                                      </SemanticTypography.Caption>

                                      <div className="flex items-center space-x-4">
                                        <SemanticTypography.Label color="gray-500" size="small">
                                          {transaction.time}
                                        </SemanticTypography.Label>
                                        {transaction.released && (
                                          <Badge
                                            hierarchy="primary"
                                            icon={CheckCheck}
                                            label="Validada"
                                          />
                                        )}
                                      </div>
                                    </div>
                                  </div>
                                  <div className="absolute bottom-0 right-full h-px w-screen bg-gray-700" />
                                  <div className="absolute bottom-0 left-0 h-px w-screen bg-gray-700" />
                                </td>

                                <td className="relative py-5"></td>

                                <td className="h-full w-2/5 py-5">
                                  <div className={cn('flex h-full items-center justify-end gap-4')}>
                                    <div className="grid space-y-1">
                                      {showErpBillBadge && (
                                        <Badge semantic="success" label={erpBillBadgeLabel} />
                                      )}
                                      {showPendingBadge && (
                                        <Badge semantic="danger" label="Pendências" />
                                      )}
                                      {!showErpBillBadge && !showPendingBadge && (
                                        <PaperclipIcon className="h-4 w-4 shrink-0 text-gray-600" />
                                      )}
                                    </div>
                                    <ChevronRightIcon className="h-4 w-4 shrink-0 text-gray-500" />
                                  </div>
                                </td>
                              </button>
                            </tr>
                          );
                        })}
                      </tbody>
                    </Fragment>
                  ))}
                </table>
              ) : (
                <EmptyState />
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
