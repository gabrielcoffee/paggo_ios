import { forwardRef } from 'react';

import { motion, HTMLMotionProps } from 'framer-motion';

type PageTransitionProps = HTMLMotionProps<'div'> & { backward?: boolean };
type PageTransitionRef = React.ForwardedRef<HTMLDivElement>;

function PageTransition(
  { backward, children, ...rest }: PageTransitionProps,
  ref: PageTransitionRef
) {
  const onTheRight = { x: backward ? '-100%' : '100%' };
  const inTheCenter = { x: 0 };
  const onTheLeft = { x: backward ? '100%' : '-100%' };

  const transition = { duration: 0.25, ease: 'easeInOut' };

  return (
    <motion.div
      ref={ref}
      id="page-transition"
      initial={onTheRight}
      animate={inTheCenter}
      exit={onTheLeft}
      transition={transition}
      className="h-full w-full"
      {...rest}
    >
      {children}
    </motion.div>
  );
}

export default forwardRef(PageTransition);
