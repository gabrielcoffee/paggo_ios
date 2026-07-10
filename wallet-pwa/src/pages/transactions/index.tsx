import { forwardRef } from 'react';

import PageTransition from '@components/transitions/PageTransition';
import TransactionsContent from '@modules/transactions';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function TransactionsHome(props: undefined, ref: IndexPageRef) {
  return (
    <PageTransition ref={ref}>
      <div className="scrollbar-hide flex flex-col gap-4 overflow-auto">
        <TransactionsContent />
      </div>
    </PageTransition>
  );
}

export default forwardRef(TransactionsHome);
