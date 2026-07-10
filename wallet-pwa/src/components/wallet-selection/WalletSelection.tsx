import { useState } from 'react';

import { WalletIcon, ChevronDown } from 'lucide-react';

import { capitalizeString } from '@paggo/core-utils';
import { Button } from '@paggo/fend/components/atoms/button/button';
import Loading from '@paggo/fend/components/atoms/loading';
import { SidebarTransition } from '@paggo/fend/components/atoms/sidebar-transition/sidebar-transition';
import { cn } from '@paggo/fend/utils';
import { useWalletService } from '@paggo/services-client/hooks';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import { useWalletStore } from '@/providers/wallet.provider';

type WalletSelectionProps = {
  fetchDeleted?: boolean;
};

export default function WalletSelection({ fetchDeleted }: WalletSelectionProps) {
  const [expanded, setExpanded] = useState(false);
  const { currentWallet, setCurrentWallet } = useWalletStore((state) => state);
  const { wallets: walletHook } = useWalletService({
    fetch: true,
    origin: 'user',
    deleted: fetchDeleted,
  });
  const { data: wallets, isLoading } = walletHook;

  return (
    <div className="z-[20] flex flex-col">
      <div className="flex justify-between">
        <div className="flex items-center justify-center gap-x-2">
          <WalletIcon className="h-4 w-4 shrink-0 text-gray-500" />
          <SemanticTypography.Label
            size="mid"
            color="gray-500"
            className="line-clamp-1 font-medium"
          >
            {`${!currentWallet?.active ? '(desativado) ' : ''}${
              currentWallet?.name
            } - ${capitalizeString(currentWallet?.organization ?? '')}`}
          </SemanticTypography.Label>
        </div>

        {isLoading && <Loading />}

        {!isLoading && wallets && wallets?.length > 1 && (
          <div className="inline-flex">
            <Button
              className={cn(
                '!stroke-white-pure shrink-0 !bg-transparent transition-all',
                expanded && 'rotate-180'
              )}
              type="button"
              hierarchy="tertiary"
              semantic="neutral"
              onClick={() => setExpanded(!expanded)}
              icon={ChevronDown}
            />
          </div>
        )}
      </div>

      <SidebarTransition
        show={expanded}
        enter="transition-all duration-150"
        enterFrom="opacity-0 h-0"
        enterTo="opacity-1 h-full"
        leave="transition-all duration-15 delay-600"
        leaveFrom="opacity-1 h-full"
        leaveTo="opacity-0 h-0"
        className="z-[20] mt-2 rounded-md bg-gray-800 px-2 py-4"
      >
        <div className="mb-4 flex gap-x-2">
          <SemanticTypography.Caption size="big" color="gray-500" highlight>
            Escolha outra Carteira Digital:
          </SemanticTypography.Caption>
        </div>

        {wallets
          ?.filter((w) => w.id !== currentWallet?.id)
          ?.map((w) => (
            <div key={w.id} className="my-4 flex justify-between">
              <SemanticTypography.Caption
                size="big"
                className="flex"
                color="white-pure line-clamp-1"
              >
                {`${!w.active ? '(desativado) ' : ''}${capitalizeString(
                  w.name
                )} - ${capitalizeString(w.organization?.legalName)}`}
              </SemanticTypography.Caption>

              <Button
                label="Selecionar"
                onClick={async () => {
                  setExpanded(!expanded);
                  await setCurrentWallet({
                    id: w.id,
                    name: w.name,
                    organization: w.organization?.legalName,
                    active: w.active,
                  });
                }}
              />
            </div>
          ))}
      </SidebarTransition>
    </div>
  );
}
