import { forwardRef, useEffect, useMemo } from 'react';

import { pdf } from '@react-pdf/renderer';
import Decimal from 'decimal.js';
import { DateTime } from 'luxon';
import { useRouter } from 'next/router';

import { formatToCPFOrCNPJ } from '@paggo/core-utils';
import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { toast } from '@paggo/ui/components/atoms/toast/toast';

import NavHeader from '@/components/header/NavHeader';
import TransactionDetail from '@/modules/transactions/detail';
import { TransactionDetailReceipt } from '@/modules/transactions/detail/TransactionDetailReceipt';
import { extractPackageId, hasErpBill } from '@/modules/transactions/wallet-payment.utils';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';
import PageTransition from '@components/transitions/PageTransition';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function TransactionId(props: undefined, ref: IndexPageRef) {
  const router = useRouter();
  const { navigateTo } = useNavigationStore();
  const { currentWallet } = useWalletStore((state) => state);
  const { payment } = useWalletPaymentService({
    fetch: true,
    id: router.query.id as string,
    walletId: currentWallet?.id,
  });

  const { data, isLoading } = payment;
  const { intent, receipt } = data || {};

  const transaction = useMemo(
    () =>
      receipt && intent?.paymentMethod
        ? {
            id: receipt.id,
            date: DateTime.fromJSDate(new Date(receipt.createdAt)).toISO() || '',
            amount: +new Decimal(receipt.amount ?? 0).div(1),
            endToEndId: receipt.endToEndId ?? undefined,
            status: receipt.status,
            customerErp: data?.customer?.erp,
            customerId: data?.customer?.id,
            hasErpBill: hasErpBill(data),
            method: intent.paymentMethod,
            digitableLine: receipt.digitableLine ?? undefined,
            authenticationData: receipt.authenticationData ?? undefined,
            dueDate: receipt.dueDate ?? undefined,
            fineAmount: receipt.fineAmount ?? undefined,
            discountAmount: receipt.discountAmount ?? undefined,
            interestAmount: receipt.interestAmount ?? undefined,
            assignor: receipt.assignor ?? undefined,
            creditParty: {
              bankCode: receipt.creditPartyBankCode ?? undefined,
              branch: receipt.creditPartyBranch ?? undefined,
              accountNumber: receipt.creditPartyAccount ?? undefined,
              receiverLegalName: receipt.creditPartyName,
              receiverDocumentNumber: receipt.creditPartyTaxId
                ? formatToCPFOrCNPJ(receipt.creditPartyTaxId, { mask: 'cpf' })
                : '',
            },
            debitParty: {
              accountNumber: receipt.debitPartyAccount,
              receiverLegalName: receipt.debitPartyName,
              receiverDocumentNumber: formatToCPFOrCNPJ(receipt.debitPartyTaxId, { mask: 'cpf' }),
            },
            description: data?.description,
            paymentId: data?.id,
            walletId: data?.walletId,
            intentAuthorId: data?.intent?.authorId,
            paymentCreatedAt: data?.createdAt,
            packageId: extractPackageId(data),
            attachments: (data?.attachments ?? []).map((a) => ({
              id: a.id,
              name: a.name,
              url: a.url,
              createdAt: a.createdAt,
            })),
          }
        : undefined,
    [
      data,
      intent?.paymentMethod,
      receipt,
    ]
  );

  const handleShare = async () => {
    if (typeof window === 'undefined' || typeof navigator === 'undefined') {
      toast({
        description: 'Recurso não disponível neste dispositivo. Entre em contato com o suporte.',
      });
      return;
    }

    const pdfBuffer = await pdf(<TransactionDetailReceipt transaction={transaction} />).toBlob();

    const file = new File(
      [pdfBuffer],
      `Comprovante_${DateTime.now().toFormat("yyyyMMdd'T'HHmmss")}.pdf`,
      { type: 'application/pdf' }
    );

    if (!navigator.share || !navigator.canShare({ files: [file] })) {
      toast({
        description: 'Recurso não disponível neste dispositivo. Entre em contato com o suporte.',
      });
      return;
    }

    return navigator.share({ files: [file] });
  };

  const isFetchReady = !!currentWallet?.id && !!router.query.id;
  const isNotFound = isFetchReady && !isLoading && !data;

  useEffect(() => {
    if (!isNotFound) return;

    toast({
      description:
        'Este pagamento não foi encontrado. Verifique se o endereço está correto e tente novamente.',
    });
    navigateTo({ screen: NavigationItem.TRANSACTIONS, replace: true });
  }, [isNotFound, navigateTo]);

  if (isNotFound) {
    return null;
  }

  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex h-full flex-col gap-4 overflow-auto pb-12">
        <NavHeader
          title="Detalhes da transação"
          leftButtonIconType="back"
          leftButtonPress={() =>
            navigateTo({
              screen: NavigationItem.TRANSACTIONS,
              replace: true,
            })
          }
          rightButtonIconType="share"
          rightButtonPress={handleShare}
        />
        {isLoading ? (
          <div className="flex items-center justify-center">
            <LoadingCircle className="text-white-pure h-8 w-8" />
          </div>
        ) : (
          <TransactionDetail transaction={transaction} />
        )}
      </div>
    </PageTransition>
  );
}

export default forwardRef(TransactionId);
