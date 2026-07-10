export const deepCompareObjects = (a: any, b: any): boolean =>
  JSON.stringify(a) === JSON.stringify(b);

export const isInStandaloneMode = () =>
  typeof window !== 'undefined'
    ? !!('standalone' in window.navigator && window.navigator.standalone)
    : false;

export function iOS() {
  return (
    ['iPad Simulator', 'iPhone Simulator', 'iPod Simulator', 'iPad', 'iPhone', 'iPod'].includes(
      navigator.platform
    ) ||
    // iPad on iOS 13 detection
    (navigator.userAgent.includes('Mac') && 'ontouchend' in document) ||
    (/iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream)
  );
}

export * from './mocks';
