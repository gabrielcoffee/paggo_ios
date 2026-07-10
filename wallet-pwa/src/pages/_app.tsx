import '@paggo/fend/styles.css';
import '@paggo/ui/styles.css';
import '@styles/globals.css';

import { useEffect, useState } from 'react';

// import * as Sentry from '@sentry/nextjs';
import { Analytics } from '@vercel/analytics/react';
import cx from 'classnames';
import { AnimatePresence } from 'framer-motion';
import Router, { useRouter } from 'next/router';
import { Provider as RWBProvider } from 'react-wrap-balancer';

import { FedexProvider } from '@paggo/fedex/fedex.provider';
import { IntercomProvider } from '@paggo/intercom';
import { DynamicModal, RootModal } from '@paggo/ui/components/atoms/dynamic-modal';
import { Toaster } from '@paggo/ui/components/atoms/toast/toast';
import poligon from '@paggo/ui/fonts/poligon';
import sfPro from '@paggo/ui/fonts/sf-pro';

import type { Session } from '@paggotech/next-auth';
import { SessionProvider } from '@paggotech/next-auth/react';

import { WalletStoreProvider } from '@/providers/wallet.provider';
import Layout from '@components/layout/Layout';
import Meta from '@components/meta/Meta';

import type { AppProps } from 'next/app';

export default function MyApp({
  Component,
  pageProps: { session, ...pageProps },
}: AppProps<{ session: Session; hydrationData?: any }>) {
  const [, setLoading] = useState(false);
  const router = useRouter();
  // Used for page transition
  useEffect(() => {
    const start = () => {
      setLoading(true);
    };
    const end = () => {
      setLoading(false);
    };
    Router.events.on('routeChangeStart', start);
    Router.events.on('routeChangeComplete', end);
    Router.events.on('routeChangeError', end);
    return () => {
      Router.events.off('routeChangeStart', start);
      Router.events.off('routeChangeComplete', end);
      Router.events.off('routeChangeError', end);
    };
  }, []);

  // useEffect(() => {
  //   if (session?.user) {
  //     if (session.user && session.user.email) {
  //       Sentry.setUser({ email: session.user.email, id: session.user.id });
  //     }
  //   }
  // }, [session.user]);

  return (
    <>
      {/**
       * Workaround to nextjs could apply font vars with portals, iframes, etc.
       * Ref: https://github.com/vercel/next.js/issues/43674
       **/}
      <style jsx global>{`
        :root {
          --font-sans: ${poligon.style.fontFamily};
        }
      `}</style>

      <SessionProvider session={session}>
        <FedexProvider>
          <Meta />
          <RWBProvider>
            <WalletStoreProvider>
              <main className={cx(sfPro.variable, poligon.variable, 'font-sans')}>
                <IntercomProvider />
                <AnimatePresence
                  mode="wait"
                  initial={false}
                  onExitComplete={() => window.scrollTo(0, 0)}
                >
                  <Layout>
                    <Component {...pageProps} key={router.asPath} />
                  </Layout>
                </AnimatePresence>
              </main>
              <DynamicModal />
              <RootModal />
            </WalletStoreProvider>
          </RWBProvider>
          <Toaster />
          <Analytics />
        </FedexProvider>
      </SessionProvider>
    </>
  );
}
