import Lottie from 'lottie-react';

import animation from './device-rotate.json';

interface DeviceRotateProps {
  width?: number;
  loop?: boolean;
}

function DeviceRotate({ loop = true, width = 140 }: DeviceRotateProps) {
  return <Lottie animationData={animation} loop={loop} style={{ width: `${width}px` }} />;
}

export { DeviceRotate };
