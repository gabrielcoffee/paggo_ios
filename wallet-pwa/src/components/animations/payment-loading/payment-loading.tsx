import Lottie from 'lottie-react';

import animation from './payment_loading.json';

interface PaymentLoadingProps {
  width?: number;
  loop?: boolean;
}

function PaymentLoading({ loop = true, width = 300 }: PaymentLoadingProps) {
  return <Lottie animationData={animation} loop={loop} style={{ width: `${width}px` }} />;
}

export { PaymentLoading };
