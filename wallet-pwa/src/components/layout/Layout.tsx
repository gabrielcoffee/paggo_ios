import { PropsWithChildren, useEffect, useRef } from 'react';

import { motion } from 'framer-motion';
import { first } from 'lodash';
import { WalletIcon } from 'lucide-react';

import { cn } from '@paggo/fend/utils';
import { useWalletService } from '@paggo/services-client/hooks';
import { LoadingAnimation } from '@paggo/ui/components/atoms/loading-animation/loading-animation';
import { ReusableAlert } from '@paggo/ui/components/molecules/reusable-alert';

import { useSession } from '@paggotech/next-auth/react';

import BottomNavigation from '@/components/bottom-navigation/BottomNavigation';
import Navbar from '@/components/navbar/Navbar';
import { Unauthenticated } from '@/components/unauthenticated/Unauthenticated';
import { useWalletStore } from '@/providers/wallet.provider';
import { isInStandaloneMode } from '@/utils';

export default function Layout({ children }: PropsWithChildren) {
  const { data: session, status } = useSession();
  const currentWallet = useWalletStore((state) => state.currentWallet);
  const setCurrentWallet = useWalletStore((state) => state.setCurrentWallet);
  const { wallets } = useWalletService({ fetch: !!session?.user, origin: 'user' });

  const hasInitialized = useRef(false);

  useEffect(() => {
    if (hasInitialized.current) return;
    if (currentWallet) return;
    if (!session?.user) return;

    const firstWallet = first(wallets.data);
    if (!firstWallet) return;

    hasInitialized.current = true;
    setCurrentWallet({
      id: firstWallet.id,
      name: firstWallet.name,
      organization: firstWallet.organization.legalName,
      active: firstWallet.active,
    });
  }, [currentWallet, session?.user, wallets.data, setCurrentWallet]);

  if (status === 'loading' || wallets.isLoading) {
    return (
      <div className="bg-white-pure flex h-screen w-screen items-center justify-center">
        <LoadingAnimation />
      </div>
    );
  }

  if (!session || !session.user) {
    return <Unauthenticated />;
  }

  if (!wallets.data?.length) {
    return (
      <div
        className={cn(
          'bg-white-pure z-[1] flex h-screen w-screen flex-col overflow-x-hidden',
          isInStandaloneMode() &&
            'h-[calc(100vh-calc(var(--safe-area-inset-bottom)+var(--safe-area-inset-top)))]'
        )}
      >
        <Navbar user={session?.user} />

        <div
          className={cn(
            'flex h-full w-full flex-col items-center justify-center overflow-auto overflow-x-hidden px-4 pt-14',
            isInStandaloneMode() && 'pt-12'
          )}
        >
          <ReusableAlert
            title="Você não tem acesso a esta página"
            description="Solicite o seu acesso ao administrador de sua empresa."
            variant="error"
            className="rounded-xl p-4"
            iconClassName="p-0 h-5 w-5"
            hideCloseButton
            titleSize="sm"
            descriptionSize="sm"
            icon={<WalletIcon className="h-6 w-6 shrink-0 stroke-1" />}
          />
        </div>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ x: 300, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 300, opacity: 0 }}
      transition={{
        type: 'spring',
        stiffness: 260,
        damping: 20,
      }}
    >
      <div
        className={cn(
          'bg-black-pure z-[1] flex h-screen w-screen flex-col overflow-x-hidden',
          isInStandaloneMode() &&
            'h-[calc(100vh-calc(var(--safe-area-inset-bottom)+var(--safe-area-inset-top)))] landscape:w-[calc(100vw-calc(var(--safe-area-inset-left)+var(--safe-area-inset-right)))]'
        )}
      >
        <Navbar user={session?.user} />

        <div
          className={cn(
            'h-full w-full flex-col overflow-auto overflow-x-hidden pt-14',
            isInStandaloneMode() && 'pt-12'
          )}
        >
          {children}
        </div>

        <BottomNavigation />
      </div>
    </motion.div>
  );
}
