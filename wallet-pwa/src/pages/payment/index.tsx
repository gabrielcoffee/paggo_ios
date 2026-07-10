import { forwardRef } from 'react';

import PageTransition from '@components/transitions/PageTransition';
import PaymentContent from '@modules/payment';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function PaymentHome(props: undefined, ref: IndexPageRef) {
  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex flex-col gap-4 overflow-auto">
        <PaymentContent />
      </div>
    </PageTransition>
  );
}

export default forwardRef(PaymentHome);
