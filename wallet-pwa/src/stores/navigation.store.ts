import Router from 'next/router';
import { create } from 'zustand';

import { NavigationItem } from '@/types/bottom-navigation.interface';

type NavigateTo = {
  screen: NavigationItem;
  id?: string;
  replace?: boolean;
};

type NavigationStore = {
  activeScreen: NavigationItem;
  setActiveScreen: (item: NavigationItem) => void;
  navigateTo: ({ id, replace, screen }: NavigateTo) => void;
};

export const getNavigationRoute = (item: NavigationItem, id?: string) => {
  switch (item) {
    case NavigationItem.HOME:
      return '/';

    case NavigationItem.PAYMENT:
      return id ? `/payment/${id}` : '/payment';

    case NavigationItem.PAYMENT_PIX:
      return '/payment/pix';

    case NavigationItem.PAYMENT_QR:
      return '/payment/qr';

    case NavigationItem.PAYMENT_QR_BY_CODE:
      return '/payment/qr-by-code';

    case NavigationItem.PAYMENT_BANKSLIP:
      return '/payment/bankslip';

    case NavigationItem.TRANSACTIONS:
      return id ? `/transactions/${id}` : '/transactions';

    default:
      break;
  }
};

export const useNavigationStore = create<NavigationStore>((set) => ({
  activeScreen: NavigationItem.HOME,
  setActiveScreen: (item) => set(() => ({ activeScreen: item })),
  navigateTo: ({ id, replace, screen }) => {
    const url = getNavigationRoute(screen, id);

    if (url && Router.asPath !== url) {
      if (replace) {
        Router.replace(url);
      } else {
        Router.push(url);
      }
    }

    set(() => ({ activeScreen: screen }));
  },
}));
