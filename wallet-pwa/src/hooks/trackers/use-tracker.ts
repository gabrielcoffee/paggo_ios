import { useCallback, useMemo } from 'react';

import { Posthog } from '@paggo/analytics/analytics';

import { trackGeneralEvents } from './events';

export enum EventCollection {
  GENERAL_EVENTS = 'general-events',
}

type EventCollectionReturnType = {
  [EventCollection.GENERAL_EVENTS]: ReturnType<typeof trackGeneralEvents>;
};

export const eventCollections = {
  [EventCollection.GENERAL_EVENTS]: trackGeneralEvents,
};

export function useTracker<E extends EventCollection>(module: E): EventCollectionReturnType[E] {
  const trackEvent = useCallback(
    (name: string, props?: Record<any, any>) => {
      Posthog.track(`[${module}] - ${name}`, props);
    },
    [module]
  );

  return useMemo(
    () => eventCollections[module](trackEvent) as EventCollectionReturnType[E],
    [module, trackEvent]
  );
}
