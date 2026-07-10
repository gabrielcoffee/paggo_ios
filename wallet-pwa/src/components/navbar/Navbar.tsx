import { Transition } from '@headlessui/react';
import { OctagonAlertIcon } from 'lucide-react';

import { isDev } from '@paggo/core-utils';
import { cn } from '@paggo/fend/utils';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import Typography from '@paggo/ui/components/atoms/typography/index';
import { CustomLink } from '@paggo/ui/components/organisms/navbar/CustomLink';

import { SessionUser } from '@paggotech/next-auth';

import { useOfflineState } from '@hooks/offline/use-offline-state';

import { isInStandaloneMode } from '@/utils';

import UserInfo from './UserInfo';

interface NavbarProps {
  user?: SessionUser;
}

export default function Navbar({ user }: NavbarProps) {
  const { offline: isOffline } = useOfflineState();

  return (
    <div
      className={cn(
        'bg-black-pure border-gray-iron-800 fixed top-0 z-[999] flex h-10 w-[100vw] shrink-0 items-center justify-between gap-4 border-b p-4 transition-colors duration-100 ease-out',
        isOffline && 'bg-red-400',
        isInStandaloneMode() && 'pb-6 pt-[calc(var(--safe-area-inset-top)+24px)]',
        !isInStandaloneMode() && 'pb-6 pt-8'
      )}
    >
      <div className="flex flex-col">
        <CustomLink />
        <div className="flex">
          {isDev && (
            <Typography.Text size="xs" color="white-pure" className="text-gray-iron-300 truncate">
              PREVIEW
            </Typography.Text>
          )}
        </div>
      </div>

      <Transition
        show={isOffline}
        className="absolute left-1/2 flex -translate-x-1/2 flex-row gap-x-2"
        leave="transition ease-out duration-100"
        leaveFrom="opacity-100"
        leaveTo="opacity-0"
        enter="transition ease-out duration-100"
        enterFrom="opacity-0"
        enterTo="opacity-100"
      >
        <OctagonAlertIcon color="white" size={20} />
        <SemanticTypography.Title color="white-pure" size="mid">
          Você está offline.
        </SemanticTypography.Title>
      </Transition>

      <div className="flex h-full items-center">{user && <UserInfo {...user} />}</div>
    </div>
  );
}
