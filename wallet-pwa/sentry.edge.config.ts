import * as Sentry from '@sentry/nextjs';

const isProd = process.env.NODE_ENV === 'production';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  enabled: isProd,
  debug: false,
  tracesSampleRate: 0.1,
  profilesSampleRate: 0.1,
});
