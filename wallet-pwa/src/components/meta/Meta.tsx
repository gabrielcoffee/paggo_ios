'use client';

import Head from 'next/head';

import { isDev } from '@paggo/core-utils';

const DOMAIN = 'https://app.paggo.ai';

export default function Meta({
  description = 'Plataforma de gestão financeira para empresas da cadeia de valor de construção civil.',
  image = `${DOMAIN}/api/og`,
  title = `${isDev ? '[Preview] - ' : ''}Paggo - Sistema Financeiro da Construção`,
}: {
  title?: string;
  description?: string;
  image?: string;
}) {
  return (
    <Head>
      <title>{title}</title>
      <meta name="description" content={description} />
      {/* <link rel="icon" href="/favicon.ico" /> */}
      <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32x32.png" />
      <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16x16.png" />
      <link rel="apple-touch-icon" href="/images/apple-touch-icon.png" />
      <link rel="icon" type="image/png" sizes="192x192" href="/images/android-chrome-192x192.png" />

      <meta charSet="utf-8" />
      <meta name="format-detection" content="telephone=no" />
      <meta
        name="viewport"
        content="viewport-fit=cover, width=device-width, initial-scale=1, user-scalable=no"
      />

      <meta name="robots" content="noindex,nofollow" />
      <meta itemProp="image" content={image} />
      <meta property="og:logo" content={`${DOMAIN}/logo.png`}></meta>
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:image" content={image} />

      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:site" content="@vercel" />
      <meta name="twitter:creator" content="@clickedClose" />
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:image" content={image} />
    </Head>
  );
}
