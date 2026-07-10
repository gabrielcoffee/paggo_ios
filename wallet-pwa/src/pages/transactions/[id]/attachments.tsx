import { forwardRef, useEffect } from 'react';

import { useRouter } from 'next/router';

import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { toast } from '@paggo/ui/components/atoms/toast/toast';

import NavHeader from '@/components/header/NavHeader';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';
import PageTransition from '@components/transitions/PageTransition';
import TransactionDetailAttachments from '@modules/transactions/detail/attachments';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function TransactionIdAttachments(props: undefined, ref: IndexPageRef) {
  const router = useRouter();
  const { navigateTo } = useNavigationStore();
  const { currentWallet } = useWalletStore((state) => state);
  const { payment } = useWalletPaymentService({
    fetch: true,
    id: router.query.id as string,
    walletId: currentWallet?.id,
  });

  const { data, isLoading } = payment;
  const notFound = !isLoading && !data;

  useEffect(() => {
    if (notFound) {
      toast({
        description:
          'Este pagamento não foi encontrado. Verifique se o endereço está correto e tente novamente.',
      });
      navigateTo({ screen: NavigationItem.TRANSACTIONS, replace: true });
    }
  }, [notFound, navigateTo]);

  if (notFound) {
    return null;
  }

  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex h-full flex-col gap-4 overflow-y-auto overflow-x-hidden pb-12">
        <NavHeader
          title="Anexos"
          leftButtonIconType="back"
          leftButtonPress={() =>
            navigateTo({
              screen: NavigationItem.TRANSACTIONS,
              replace: true,
            })
          }
        />

        {isLoading ? (
          <div className="flex items-center justify-center">
            <LoadingCircle className="text-white-pure h-8 w-8" />
          </div>
        ) : (
          <TransactionDetailAttachments walletPayment={data} />
        )}
      </div>
    </PageTransition>
  );
}

export default forwardRef(TransactionIdAttachments);
