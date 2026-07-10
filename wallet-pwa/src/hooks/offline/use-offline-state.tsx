import { useEffect, useState } from 'react';

export const useOfflineState = () => {
  const [offline, setOffline] = useState(false);

  useEffect(() => {
    const handleSetOnline = () => setOffline(false);
    const handleSetOffline = () => setOffline(true);
    window.addEventListener('online', handleSetOnline);
    window.addEventListener('offline', handleSetOffline);

    return () => {
      window.removeEventListener('online', handleSetOnline);
      window.removeEventListener('offline', handleSetOffline);
    };
  }, []);

  return { offline };
};
