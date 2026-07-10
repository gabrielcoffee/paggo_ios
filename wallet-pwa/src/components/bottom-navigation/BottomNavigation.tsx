import { useEffect } from 'react';

import { CircleDollarSignIcon, HomeIcon, ListChecksIcon } from 'lucide-react';
import minimatch from 'minimatch';
import { useRouter } from 'next/router';

import { cn } from '@paggo/fend/utils';

import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

const navigationItems = [
  {
    key: NavigationItem.HOME,
    href: '/',
    title: 'Início',
    icon: HomeIcon,
  },
  {
    key: NavigationItem.PAYMENT,
    href: '/payment',
    title: 'Pagar',
    icon: CircleDollarSignIcon,
  },
  {
    key: NavigationItem.TRANSACTIONS,
    href: '/transactions',
    title: 'Transações',
    icon: ListChecksIcon,
  },
];

const hiddenRoutes = ['/payment/*', '/transactions/**'];

export default function BottomNavigation() {
  const { activeScreen, navigateTo, setActiveScreen } = useNavigationStore();
  const router = useRouter();

  useEffect(() => {
    const matchedItem = navigationItems.find((i) => {
      if (i.href === router.pathname) return true;

      const [basePath] = router.pathname.split('/').filter((i) => !!i);
      return `/${basePath}` === i.href;
    });

    if (!matchedItem) return;

    const currentScreen = useNavigationStore.getState().activeScreen;
    if (matchedItem.key === currentScreen) return;

    setActiveScreen(matchedItem.key);
  }, [router.pathname, setActiveScreen]);

  return (
    <div
      className={cn(
        'bg-gray-iron-900 fixed bottom-10 left-1/2 z-[20] w-full max-w-[220px] -translate-x-1/2 rounded-full p-2',
        !!hiddenRoutes.find((i) => minimatch(router.asPath, i)) && 'hidden'
      )}
    >
      <section id="bottom-navigation">
        <div id="tabs" className="flex justify-between">
          {navigationItems.map((nav) => {
            const isActive = nav.key === activeScreen;

            return (
              <button
                key={nav.key}
                onClick={() => navigateTo({ screen: nav.key, replace: true })}
                className={cn(
                  'flex w-full flex-col items-center justify-center rounded-full px-2 py-3 text-center',
                  isActive && 'text-white-pure bg-black-pure'
                )}
              >
                <nav.icon
                  strokeWidth={1.5}
                  className={cn(
                    'lex justify-center',
                    isActive ? 'text-white-pure' : 'text-content-neutral-mid'
                  )}
                />
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}
