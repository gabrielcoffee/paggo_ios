'use client';

import { useCallback, useEffect, useState } from 'react';

import { useRouter } from 'next/router';

import { toast } from '@paggo/fend/components/atoms/toast/toast';
import { Button } from '@paggo/ui/components/atoms/button/button';

import { getGeolocationPermissionStatus } from '@components/location-permissions/LocationPermissions';

export function useCheckLocationPermissions() {
  const [checkingLocation, setCheckingLocation] = useState(true);
  const router = useRouter();

  const onSuccess = useCallback((position: GeolocationPosition) => {
    setCheckingLocation(false);
    return position.coords;
  }, []);

  const onError = useCallback(
    (error: GeolocationPositionError) => {
      if (error.code === error.PERMISSION_DENIED) {
        toast({
          description:
            'A permissão foi negada. Você precisa permitir o uso da localização antes de continuar.',
        });
        return;
      }

      if (error.code === error.TIMEOUT) {
        toast({
          title:
            'O tempo para aceitar a localização se esgotou. Atualize a página para tentar novamente.',
          description: <Button label="Atualizar" onClick={() => router.reload()} />,
        });
        return;
      }

      toast({ description: error.message });
    },
    [router]
  );

  const checkPermissions = useCallback(async () => {
    if ('permissions' in navigator) {
      const { state } = await navigator.permissions.query({ name: 'geolocation' });

      if (state === 'prompt') {
        await getGeolocationPermissionStatus();
        navigator.geolocation.getCurrentPosition(onSuccess, onError);
        return;
      }

      if (state === 'granted') {
        setCheckingLocation(false);
        return;
      }

      if (state === 'denied') {
        setCheckingLocation(true);
      }
    }
  }, [onError, onSuccess]);

  useEffect(() => {
    checkPermissions();
  }, [checkPermissions]);

  return { checkingLocation, onSuccess, onError };
}
