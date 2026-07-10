import Lottie from 'lottie-react';

import animation from './payment-successful.json';

interface PaymentSuccessfulProps {
  width?: number;
  loop?: boolean;
}

function PaymentSuccessful({ loop = true, width = 300 }: PaymentSuccessfulProps) {
  return <Lottie animationData={animation} loop={loop} style={{ width: `${width}px` }} />;
}

export { PaymentSuccessful };
