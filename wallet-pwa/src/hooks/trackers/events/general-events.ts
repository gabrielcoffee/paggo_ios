import { Dict } from '@paggo/fend-utils/assertion';

export const trackGeneralEvents = (trackEvent: (name: string, props?: Dict) => any) => {
  const trackLoginFailed = (params?: string) => trackEvent('Failed to login', { params });
  const trackLoginSucceded = (provider: string, email: string) =>
    trackEvent('Logged in', { provider, email });

  const trackErrorPage = (params: string) => trackEvent('Entered error page', { params });

  return {
    trackLoginFailed,
    trackErrorPage,
    trackLoginSucceded,
  };
};
