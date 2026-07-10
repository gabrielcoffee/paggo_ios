import PaggoTailwindConfig from '@paggo/tailwind-config/tailwind.config';

import type { Config } from 'tailwindcss';

const config: Pick<Config, 'content' | 'presets'> = {
  content: [
    '../../packages/paggo-fend/{components,enums,exported,hooks,layouts,legacy,theme,third-party,types,utils}/**/*.{ts,tsx}',
    '../../packages/paggo-fend/*.{ts,tsx}',
    '../../packages/paggo-ui/{components,core,hocs,hooks,ilustrations,legacy,types,utils}/**/*.{ts,tsx}',
    '../../packages/paggo-ui/*.{ts,tsx}',
    '../../packages/paggo-ai/{components,hooks}/**/*.{ts,tsx}',
    '../../packages/paggo-ai/*.{ts,tsx}',
    '../../packages/paggo-flow/payment-methods/**/*.{ts,tsx}',
    '../../packages/paggo-flow/*.{ts,tsx}',
    './src/{components,hooks,labs,lib,modules,pages,stores,styles,utils}/**/*.{ts,tsx}',
    './src/*.{ts,tsx}',
  ],
  presets: [PaggoTailwindConfig],
};

export default config;
