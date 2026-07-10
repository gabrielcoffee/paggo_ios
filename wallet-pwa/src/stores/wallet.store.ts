import { createStore } from 'zustand/vanilla';

type CurrentWallet = {
  id: string;
  name: string;
  organization: string;
  active: boolean;
};

export type WalletState = {
  currentWallet: CurrentWallet | null;
};

export type WalletActions = {
  setCurrentWallet: (wallet: CurrentWallet) => Promise<void>;
};

export type WalletStore = WalletState & WalletActions;

export const defaultInitState: WalletState = {
  currentWallet: null,
};

export const createWalletStore = (initState: WalletState = defaultInitState) => {
  return createStore<WalletStore>()((set) => ({
    ...initState,
    setCurrentWallet: async (wallet: CurrentWallet) => {
      set(() => ({
        currentWallet: wallet,
      }));
    },
  }));
};
