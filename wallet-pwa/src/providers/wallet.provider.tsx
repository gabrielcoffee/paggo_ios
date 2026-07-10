'use client';

import { type ReactNode, createContext, useRef, useContext } from 'react';

import { type StoreApi, useStore } from 'zustand';

import { type WalletStore, createWalletStore } from '@/stores/wallet.store';

export const WalletStoreContext = createContext<StoreApi<WalletStore> | null>(null);

export interface WalletStoreProviderProps {
  children: ReactNode;
}

export const WalletStoreProvider = ({ children }: WalletStoreProviderProps) => {
  const storeRef = useRef<StoreApi<WalletStore>>();
  if (!storeRef.current) {
    storeRef.current = createWalletStore();
  }

  return (
    <WalletStoreContext.Provider value={storeRef.current}>{children}</WalletStoreContext.Provider>
  );
};

// eslint-disable-next-line comma-spacing
export const useWalletStore = <T,>(selector: (store: WalletStore) => T): T => {
  const walletStoreContext = useContext(WalletStoreContext);

  if (!walletStoreContext) {
    throw new Error('useWalletStore must be use within WalletStoreProvider');
  }

  return useStore(walletStoreContext, selector);
};
