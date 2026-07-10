import { PropsWithChildren, useMemo, useState } from 'react';

import {
  CircleDollarSignIcon,
  CircleHelpIcon,
  ListChecksIcon,
  QrCodeIcon,
  RefreshCcw,
  EyeOff,
  Eye,
} from 'lucide-react';
import { mutate } from 'swr';

import { formatNumberReal, getGreeting } from '@paggo/core-utils';
import { Button } from '@paggo/fend/components/atoms/button/button';
import { Icon } from '@paggo/fend/components/atoms/icon/icon';
import { ProgressBar } from '@paggo/fend/components/atoms/progress/progress-bar';
import { Card } from '@paggo/fend/components/molecules/card/index';
import { cn } from '@paggo/fend/utils';
import { useWalletService } from '@paggo/services-client/hooks';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import { useSession } from '@paggotech/next-auth/react';

import WalletSelection from '@/components/wallet-selection/WalletSelection';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

type LinkCardProps = {
  id?: string;
  title: string;
  onClick?: (e: any) => void;
  icon?: React.ReactElement;
};

function LinkCard({ icon, id, onClick, title }: LinkCardProps) {
  return (
    <a
      id={id}
      onClick={onClick}
      className="flex w-12 cursor-pointer flex-col items-center justify-start gap-2"
    >
      <Card className="rounded-lg bg-gray-800 shadow-sm">
        <Card.Container className="flex flex-col items-center !p-4">{icon}</Card.Container>
      </Card>

      <SemanticTypography.Label size="small" color="white-pure">
        {title}
      </SemanticTypography.Label>
    </a>
  );
}

function Container({ children }: PropsWithChildren) {
  return (
    <div className="scrollbar-hide">
      <div className="mx-auto h-fit max-w-7xl py-4 sm:px-6 lg:px-8">{children}</div>
    </div>
  );
}

export default function HomeContent() {
  const { data: session } = useSession();
  const [hideLimits, setHideLimits] = useState(false);
  const { currentWallet } = useWalletStore((state) => state);
  const { navigateTo } = useNavigationStore();
  const { userWalletBalance: balanceHook, wallet } = useWalletService({
    id: currentWallet?.id,
    balance: true,
    origin: 'user',
  });

  const { data: walletHook, isLoading } = wallet;
  const { data: { balance } = {}, isLoading: balanceIsLoading } = balanceHook;
  const { id, limit, maximumLimit } = walletHook || {};

  const usedLimit = useMemo(() => (maximumLimit ?? 0) - (limit ?? 0), [maximumLimit, limit]);
  const usedLimitProgress = useMemo(
    () => Math.round((usedLimit / (maximumLimit ?? 0)) * 100),
    [usedLimit, maximumLimit]
  );
  const availableLimit = useMemo(() => {
    if (typeof balance === 'undefined' || !limit) return;
    if (balance >= limit) return { limit };

    return {
      limit: balance,
      disclaimer:
        'O Limite disponível está menor pois está refletindo o saldo da conta. Solicite a recarga da conta com o seu time financeiro.',
    };
  }, [limit, balance]);

  const fullName = useMemo(() => {
    const [firstName, lastName] = session?.user?.name.split(' ') || [];

    return `${firstName} ${lastName}`;
  }, [session?.user?.name]);

  return (
    <Container>
      <div className="flex flex-col gap-2">
        <div className="bg-gray-25 flex flex-col gap-4 px-4 py-2">
          <div className="flex flex-col">
            <SemanticTypography.Overhead size="big" color="gray-500">
              {getGreeting()},
            </SemanticTypography.Overhead>

            <SemanticTypography.Title size="mid" color="white-pure">
              {fullName}
            </SemanticTypography.Title>
          </div>

          <WalletSelection />
        </div>

        <div
          className={cn('my-2 flex flex-col px-4', (isLoading || balanceIsLoading) && 'opacity-40')}
        >
          <Card className="border-gray-iron-900 border bg-gray-900 p-2">
            <div className="flex flex-col space-y-1.5 p-3 pb-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-x-2">
                  <SemanticTypography.Label
                    as="p"
                    size="mid"
                    className="text-muted-foreground text-white-pure font-semibold"
                  >
                    Limite Disponível
                  </SemanticTypography.Label>
                </div>

                <div className="flex items-center gap-x-4">
                  <Button
                    className="!stroke-white-pure shrink-0 !bg-transparent"
                    icon={!hideLimits ? EyeOff : Eye}
                    onClick={() => setHideLimits(!hideLimits)}
                  />

                  {id && (
                    <Button
                      onClick={() => {
                        mutate(`/api/wallets/${currentWallet?.id}`, undefined, true);
                        mutate(
                          `/api/wallets/${currentWallet?.id}/baas/account/balance`,
                          undefined,
                          true
                        );
                      }}
                      className="!stroke-white-pure shrink-0 !bg-transparent"
                      icon={RefreshCcw}
                    />
                  )}
                </div>
              </div>

              <SemanticTypography.Title
                as="h3"
                className="mb-4 text-4xl leading-none tracking-tight"
              >
                <div className="flex items-center gap-x-2">
                  <SemanticTypography.Display size="small" color="white-pure">
                    {hideLimits ? (
                      <div className="h-[22px]">
                        <div className="bg-gray-true-900 h-full w-40 rounded-md" />
                      </div>
                    ) : (
                      formatNumberReal((availableLimit?.limit ?? 0) / 100)
                    )}
                  </SemanticTypography.Display>

                  {availableLimit?.disclaimer && (
                    <Icon
                      semantic="warning"
                      size="mid"
                      className="!stroke-[#FFECB3] !text-[#FFECB3]"
                    />
                  )}
                </div>
              </SemanticTypography.Title>

              <ProgressBar
                className="bg-gray-700"
                classNames={{ progressIndicator: 'bg-orange-dark-900' }}
                value={hideLimits ? 0 : usedLimitProgress}
              />
            </div>

            <Card.Container className="flex w-full justify-between">
              <div className="flex w-full flex-col items-start">
                <SemanticTypography.Caption size="big" color="white-pure">
                  {hideLimits ? '-' : formatNumberReal(usedLimit / 100)}
                </SemanticTypography.Caption>

                <SemanticTypography.Caption size="big" color="gray-500" className="text-left">
                  Utilizado
                </SemanticTypography.Caption>
              </div>

              <div className="flex w-full flex-col items-end">
                <SemanticTypography.Caption size="big" color="white-pure">
                  {hideLimits ? '-' : formatNumberReal((maximumLimit ?? 0) / 100)}
                </SemanticTypography.Caption>

                <SemanticTypography.Caption size="big" color="gray-500" className="text-right">
                  Total
                </SemanticTypography.Caption>
              </div>
            </Card.Container>
          </Card>
        </div>

        {availableLimit?.disclaimer && (
          <div className="flex w-full items-center gap-x-2 px-4">
            <Icon semantic="warning" size="mid" className="!stroke-[#FFECB3] !text-[#FFECB3]" />

            <SemanticTypography.Body size="big" className="!text-[#FFECB3]">
              {availableLimit.disclaimer}
            </SemanticTypography.Body>
          </div>
        )}

        <div className="my-2 flex w-full justify-between gap-x-4 px-4">
          <LinkCard
            title="Pix QR"
            icon={<QrCodeIcon className="text-white-pure h-5 w-5" />}
            onClick={(e) => {
              e.stopPropagation();
              navigateTo({ screen: NavigationItem.PAYMENT_QR });
            }}
          />

          <LinkCard
            title="Pagar"
            icon={<CircleDollarSignIcon className="text-white-pure h-5 w-5" />}
            onClick={(e) => {
              e.stopPropagation();
              navigateTo({ screen: NavigationItem.PAYMENT });
            }}
          />

          <LinkCard
            icon={<ListChecksIcon className="text-white-pure h-5 w-5" />}
            title="Extrato"
            onClick={(e) => {
              e.stopPropagation();
              navigateTo({ screen: NavigationItem.TRANSACTIONS });
            }}
          />

          <LinkCard
            id="custom_intercom_launcher"
            title="Ajuda"
            icon={<CircleHelpIcon className="text-white-pure h-5 w-5" />}
          />
        </div>
      </div>
    </Container>
  );
}
