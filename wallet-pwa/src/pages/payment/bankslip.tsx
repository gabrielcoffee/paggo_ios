import { forwardRef } from 'react';

import { LocationPermissions } from '@/components/location-permissions/LocationPermissions';
import PageTransition from '@/components/transitions/PageTransition';
import { useCheckLocationPermissions } from '@/hooks/check-location-permissions/use-check-location-permissions';
import { PaymentBarcode } from '@/modules/payment/barcode';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function PaymentBankslipHome(_: undefined, ref: IndexPageRef) {
  const { checkingLocation, onError, onSuccess } = useCheckLocationPermissions();

  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex h-full w-full flex-col gap-4 overflow-auto overflow-x-hidden pb-12">
        {checkingLocation && <LocationPermissions onSuccess={onSuccess} onError={onError} />}

        {!checkingLocation && <PaymentBarcode />}
      </div>
    </PageTransition>
  );
}

export default forwardRef(PaymentBankslipHome);
