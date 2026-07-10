import Lottie from 'lottie-react';

import animation from './animation.json';

interface PaymentFailedProps {
  width?: number;
  loop?: boolean;
}

function PaymentFailed({ loop = true, width = 300 }: PaymentFailedProps) {
  return <Lottie animationData={animation} loop={loop} style={{ width: `${width}px` }} />;
}

export { PaymentFailed };
