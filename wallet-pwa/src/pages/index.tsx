import { forwardRef } from 'react';

import PageTransition from '@components/transitions/PageTransition';
import HomeContent from '@modules/home';

type IndexPageRef = React.ForwardedRef<HTMLDivElement>;

function Home(props: undefined, ref: IndexPageRef) {
  return (
    <PageTransition ref={ref} backward>
      <div className="scrollbar-hide flex flex-col gap-4 overflow-auto">
        <HomeContent />
      </div>
    </PageTransition>
  );
}

export default forwardRef(Home);
