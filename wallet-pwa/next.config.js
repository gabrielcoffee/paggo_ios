/**
 * @type {import('next').NextConfig}
 */

const { PrismaPlugin } = require('@prisma/nextjs-monorepo-workaround-plugin');
const { withSentryConfig } = require('@sentry/nextjs');
const withPWA = require('next-pwa')({
  dest: 'public',
  disable: process.env.NODE_ENV === 'development',
  maximumFileSizeToCacheInBytes: 50000000,
});

const { IGNORE_PRISMA_PLUGIN } = process.env;

const ignorePrismaWorkaround = IGNORE_PRISMA_PLUGIN === 'true';

const nextConfig = {
  reactStrictMode: false,
  transpilePackages: ['@paggo/ui', '@paggo/utils'],
  swcMinify: true,
  experimental: {
    serverMinification: false,
  },
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'lh3.googleusercontent.com',
        port: '',
      },
      {
        protocol: 'https',
        hostname: '*.dicebear.com',
        port: '',
      },
      {
        protocol: 'https',
        hostname: 'files.paggo.ai',
        port: '',
      },
      {
        protocol: 'https',
        hostname: 'cdn.paggo.ai',
        port: '',
      },
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
        port: '',
      },
    ],
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [{ key: 'X-Frame-Options', value: 'SAMEORIGIN' }],
      },
    ];
  },
  webpack: (config, { isServer }) => {
    if (isServer && !ignorePrismaWorkaround) {
      config.plugins = [...config.plugins, new PrismaPlugin()];
    }

    config.resolve.fallback = {
      ...config.resolve.fallback, // if you miss it, all the other options in fallback, specified
      fs: false, // the solution
    };

    return config;
  },
};

const sentryConfig = withSentryConfig(nextConfig, {
  org: 'paggo',
  project: 'platform-wallet-pwa',
  authToken: process.env.SENTRY_AUTH_TOKEN,
  silent: !process.env.CI,
  tunnelRoute: '/monitoring',
  widenClientFileUpload: process.env.VERCEL_ENV === 'production',
  transpileClientSDK: true,
  hideSourceMaps: true,
  disableLogger: true,
  automaticVercelMonitors: true,
  sourcemaps: {
    deleteSourcemapsAfterUpload: true,
  },
});

module.exports = withPWA(sentryConfig);
