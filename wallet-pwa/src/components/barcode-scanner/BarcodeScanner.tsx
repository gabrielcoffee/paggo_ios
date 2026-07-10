import { useEffect, useMemo, useRef, useState } from 'react';

import { Transition } from '@headlessui/react';
import { X, Keyboard, FlashlightOff, Flashlight } from 'lucide-react';

import { cn } from '@paggo/fend/utils';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { useWindowOrientation } from '@paggo/ui/hooks/use-window-orientation';

import { useZxing } from '@/hooks/zxing';
import { DeviceRotate } from '@components/animations/device-rotate';

import type { Exception, Result } from '@zxing/library';

const constraints: MediaStreamConstraints = {
  audio: false,
  video: {
    facingMode: { ideal: 'environment' },
    aspectRatio: 16 / 9,
    frameRate: { min: 10, ideal: 30, max: 60 },
    width: { min: 640, ideal: 1920 },
    height: { min: 480, ideal: 1080 },
    advanced: [
      { width: 1920, height: 1080, aspectRatio: 16 / 9 },
      { width: 1920, height: 1280 },
      { aspectRatio: 1.333 },
    ],
  },
};

// const hints = new Map();
// const formats = [BarcodeFormat.ITF, BarcodeFormat.CODE_128];
// hints.set(DecodeHintType.POSSIBLE_FORMATS, formats);

type BarCodeScannerProps = {
  onResult?: (text: any) => void;
  handleCloseCamera?: (goBack?: boolean) => void;
};

const BarCodeScanner = ({ handleCloseCamera, onResult }: BarCodeScannerProps): JSX.Element => {
  const [cameraOpen, setCameraOpen] = useState<boolean>(false);
  const [torchEnabled, setTorchEnabled] = useState(false);

  const lastResult = useRef<string | null>(null);

  const { landscape, portrait } = useWindowOrientation();

  const isPortraitMode = useMemo(() => portrait, [portrait]);
  const isLandscapeMode = useMemo(() => landscape, [landscape]);

  const {
    ref: videoRef,
    stop,
    torch,
  } = useZxing({
    paused: !cameraOpen,
    constraints,
    onDecodeResult: (result: Result) => {
      if (!result) return;
      if (lastResult.current === result.getText()) {
        return;
      }

      lastResult.current = result.getText();
      onResult && onResult(result.getText());
    },
    onDecodeError: (error: Exception) => {
      if (error) {
        console.log('Error while trying to scan barcode :>> ', error);
      }
    },
    onError: () => {
      setCameraOpen(false);
      handleCloseCamera && handleCloseCamera(true);
    },
  });

  const torchSupported = useMemo(() => !!torch.isAvailable, [torch.isAvailable]);

  const handleToggleFlashlight = async () => {
    await torch.toggle();
    setTorchEnabled(!torchEnabled);
  };

  const stopScanner = async () => {
    stop();
    handleCloseCamera && handleCloseCamera();
  };

  useEffect(() => {
    if (!cameraOpen && isLandscapeMode) {
      setCameraOpen(true);
    }

    if (cameraOpen && isPortraitMode) {
      setCameraOpen(false);
    }
  }, [cameraOpen, isLandscapeMode, isPortraitMode]);

  useEffect(() => {
    const transitionElement = document.getElementById('page-transition');

    if (transitionElement) {
      transitionElement.removeAttribute('style');
    }
  }, []);

  return (
    <>
      <div className="bg-black-pure absolute left-0 top-0 flex h-full w-full flex-col items-center justify-center gap-4 overflow-hidden px-4 landscape:hidden">
        <div className="absolute right-10 top-14">
          <Button icon={X} onClick={stopScanner} />
        </div>

        <div className="mb-4 -scale-x-100">
          <DeviceRotate />
        </div>

        <SemanticTypography.Overhead
          color="white-pure"
          size="big"
          className="text-center"
          highlight
        >
          Por favor, gire o seu dispositivo para abrir a câmera
        </SemanticTypography.Overhead>
      </div>

      <Transition
        show={isLandscapeMode}
        enter="transform transition ease-in-out duration-500"
        enterFrom="translate-y-full"
        enterTo="translate-y-0"
        leave="transform transition ease-in-out duration-500"
        leaveFrom="translate-y-0"
        leaveTo="translate-y-full"
        className="absolute left-0 top-0 h-full w-screen overflow-x-hidden portrait:hidden"
      >
        <div className="overflow-hidden">
          <div className="absolute left-0 top-0 z-10 h-1/3 w-full bg-gray-800 opacity-95">
            <div className="flex h-full w-full items-start justify-end px-8 py-4">
              <Button icon={X} onClick={stopScanner} />
            </div>
          </div>

          <div className="absolute bottom-0 left-0 z-10 h-1/3 w-full bg-gray-800 opacity-95">
            <div className={cn('flex h-full w-full items-center justify-evenly px-8')}>
              <Button icon={Keyboard} label="Digitar código de barras" onClick={stopScanner} />

              <Button
                disabled={!torchSupported}
                onClick={handleToggleFlashlight}
                icon={torchEnabled ? FlashlightOff : Flashlight}
                label="Lanterna"
              />
            </div>
          </div>

          <svg
            width="100px"
            height="100px"
            viewBox="0 0 100 100"
            className="bg-black-pure absolute left-0 top-0 z-[2] box-border h-full w-full opacity-10"
          />

          <svg
            width="100px"
            height="100px"
            viewBox="0 0 100 100"
            className="bg-white-opacity-20 absolute left-1/2 top-1/2 z-10 box-border h-1/3 w-full -translate-x-1/2 -translate-y-1/2"
          />
        </div>

        <video
          id="video"
          ref={videoRef}
          className="bg-black-pure fixed z-[1] h-full w-full overflow-hidden"
          autoPlay
          muted
          playsInline
        />
      </Transition>
    </>
  );
};

export default BarCodeScanner;
