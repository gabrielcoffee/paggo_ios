import { forwardRef, useEffect } from 'react';

import { ChevronLeft, X } from 'lucide-react';
import { useRouter } from 'next/router';

import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';

import { useSession } from '@paggotech/next-auth/react';

import PageTransition from '@/components/transitions/PageTransition';
import { AttachmentsSection } from '@/modules/transactions/payment-info/AttachmentsSection';
import { PaymentInfoForm } from '@/modules/transactions/payment-info/PaymentInfoForm';
import { extractPackageId, hasErpBill } from '@/modules/transactions/wallet-payment.utils';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function TransactionPaymentInfo(props: undefined, ref: IndexPageRef) {
  const router = useRouter();
  const { navigateTo } = useNavigationStore();
  const { currentWallet } = useWalletStore((state) => state);
  const { payment } = useWalletPaymentService({
    fetch: true,
    id: router.query.id as string,
    walletId: currentWallet?.id,
  });

  const { data, isLoading } = payment;
  const { data: session } = useSession();
  const sessionUserId = (session?.user as { userId?: string } | undefined)?.userId;
  const fromPayment = router.query.from === 'payment';

  const notFound = !isLoading && !data;

  useEffect(() => {
    if (!notFound) return;
    toast({
      description:
        'Este pagamento não foi encontrado. Verifique se o endereço está correto e tente novamente.',
    });
    navigateTo({ screen: NavigationItem.TRANSACTIONS, replace: true });
  }, [notFound, navigateTo]);

  if (notFound) return null;

  function handleNavigateBack() {
    if (fromPayment) {
      navigateTo({ screen: NavigationItem.HOME, replace: true });
      return;
    }
    router.back();
  }

  const canEdit =
    !!data?.intent?.authorId && !!sessionUserId && data.intent.authorId === sessionUserId;

  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex h-full flex-col overflow-x-hidden pb-12">
        <div className="flex h-14 items-center justify-between border-b border-gray-700 px-2">
          <Button
            hierarchy="tertiary"
            icon={ChevronLeft}
            label="Voltar"
            onClick={handleNavigateBack}
          />
          <SemanticTypography.Title size="big" color="white-pure" className="font-medium">
            Informações do pagamento
          </SemanticTypography.Title>
          <Button
            hierarchy="tertiary"
            icon={X}
            aria-label="Fechar"
            onClick={handleNavigateBack}
          />
        </div>

        {isLoading || !data ? (
          <div className="flex flex-1 items-center justify-center">
            <LoadingCircle className="text-white-pure h-8 w-8" />
          </div>
        ) : (
          <div className="flex flex-col gap-6 px-4 pt-4 sm:px-6 lg:px-8">
            <PaymentInfoForm
              canEdit={canEdit}
              customerErp={data.customer?.erp}
              hasExistingBill={hasErpBill(data)}
              initialDescription={data.description}
              packageId={
                (router.query.packageId as string | undefined) ?? extractPackageId(data)
              }
              paymentAmountCents={data.amount}
              paymentConfirmed={data.status === 'CONFIRMED'}
              paymentDate={data.paidAt ?? data.createdAt}
              paymentId={data.id}
              paymentMethod={data.intent?.paymentMethod}
              walletId={data.walletId}
            />

            <div className="border-t border-gray-700" />

            <AttachmentsSection
              attachments={(data.attachments ?? []).map((a) => ({
                id: a.id,
                name: a.name,
                url: a.url,
                createdAt: a.createdAt,
              }))}
              canEdit={canEdit}
              description={data.description}
              paymentId={data.id}
              walletId={data.walletId}
            />

            <div className="space-y-2 pt-4">
              <Button
                hierarchy="secondary"
                contentWidth="fill"
                label="Concluir"
                onClick={handleNavigateBack}
              />
            </div>
          </div>
        )}
      </div>
    </PageTransition>
  );
}

export default forwardRef(TransactionPaymentInfo);
