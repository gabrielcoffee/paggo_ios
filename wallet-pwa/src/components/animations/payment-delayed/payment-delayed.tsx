import Lottie from 'lottie-react';

import animation from './payment-delayed.json';

interface PaymentDelayedProps {
  width?: number;
  loop?: boolean;
}

function PaymentDelayed({ loop = true, width = 300 }: PaymentDelayedProps) {
  return <Lottie animationData={animation} loop={loop} style={{ width: `${width}px` }} />;
}

export { PaymentDelayed };
