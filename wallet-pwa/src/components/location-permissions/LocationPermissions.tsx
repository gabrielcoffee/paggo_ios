import { MapPinIcon, Navigation } from 'lucide-react';

import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

type LocationPermissionsProps = {
  onSuccess: (position: GeolocationPosition) => void;
  onError: (error: GeolocationPositionError) => void;
};

/**
 * Checks the status of the geolocation permission asynchronously.
 *
 * Returns the permission status: `'denied'`, `'granted'`, or `'prompt'`.
 *
 * Includes a fallback for browsers which do not support the Web Permissions API.
 */
export async function getGeolocationPermissionStatus(): Promise<'denied' | 'granted' | 'prompt'> {
  if ('permissions' in navigator) {
    return (await navigator.permissions.query({ name: 'geolocation' })).state;
  }

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      // successfully got location
      () => resolve('granted'),
      (error) => {
        // permission denied
        if (error.code === error.PERMISSION_DENIED) resolve('denied');

        // some other error, but not one which is related to a denied permission
        resolve('granted');
      },
      {
        enableHighAccuracy: true,
        maximumAge: Infinity,
        timeout: 0,
      }
    );
  });
}

export function LocationPermissions({ onError, onSuccess }: LocationPermissionsProps) {
  const handleSuccess = (position: GeolocationPosition) => {
    onSuccess(position);
  };

  const handleError = (error: GeolocationPositionError) => {
    onError(error);
  };

  return (
    <div className="flex flex-col items-center justify-center gap-4 overflow-x-hidden p-4">
      <div className="my-4 flex">
        <MapPinIcon className="text-white-pure h-16 w-16 shrink-0 stroke-1" />
      </div>

      <div className="my-4 flex max-w-full flex-col items-center justify-center gap-4">
        <SemanticTypography.Display
          size="small"
          color="white-pure"
          className="flex-wrap !whitespace-normal text-center"
        >
          Precisamos da sua localização para realizar o pagamento.
        </SemanticTypography.Display>

        <SemanticTypography.Label size="big" className="text-center" color="gray-500">
          Ao ser solicitado, clique em "Permitir".
        </SemanticTypography.Label>
      </div>

      <div className="my-4">
        <Button
          label="Solicitar"
          icon={Navigation}
          onClick={async () => {
            await getGeolocationPermissionStatus();
            navigator.geolocation.getCurrentPosition(handleSuccess, handleError);
          }}
        />
      </div>
    </div>
  );
}
