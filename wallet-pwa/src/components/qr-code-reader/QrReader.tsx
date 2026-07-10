/* eslint-disable react-hooks/exhaustive-deps */
import { useEffect, useRef, useState } from 'react';

import { useWindowSize } from '@paggo/fend-utils/hooks';
import { toast } from '@paggo/ui/components/atoms/toast/toast';

import QrScanner from '@paggotech/qr-scanner';

import { OverlayInformation } from './OverlayInformation';

type QrReaderProps = {
  onResult?: (text: any) => void;
  handleCloseCamera?: (goBack?: boolean) => void;
};

const QrReader = ({ handleCloseCamera, onResult }: QrReaderProps) => {
  const scanner = useRef<QrScanner>();
  const videoRef = useRef<HTMLVideoElement>(null);
  const overlayRef = useRef<HTMLDivElement>(null);
  const lastResult = useRef<string | null>(null);
  const [cameraOpen, setCameraOpen] = useState<boolean>(true);

  const { isDesktop } = useWindowSize();

  const onScanSuccess = (result: QrScanner.ScanResult) => {
    if (!result) return;
    if (lastResult.current === result.data) {
      return;
    }

    lastResult.current = result.data;
    onResult && onResult(result.data);
    handleCloseCamera && handleCloseCamera(false);
  };

  const onScanFail = (err: string | Error) => {
    console.log(err);
  };

  useEffect(() => {
    if (videoRef?.current && !scanner.current) {
      scanner.current = new QrScanner(videoRef?.current, onScanSuccess, {
        onDecodeError: onScanFail,
        preferredCamera: 'environment',
        highlightScanRegion: true,
        overlay: overlayRef?.current || undefined,
        videoConstraints: {
          aspectRatio: { exact: isDesktop ? 9 / 16 : 16 / 9 },
          frameRate: { min: 10, ideal: 30, max: 60 },
        },
      });

      scanner?.current
        ?.start()
        .then(() => setCameraOpen(true))
        .catch((err) => {
          if (err) setCameraOpen(false);
        });
    }

    return () => {
      if (!videoRef?.current) {
        scanner?.current?.stop();
      }
    };
  }, []);

  useEffect(() => {
    if (!cameraOpen) {
      toast({
        description: 'Você precisa permitir o uso da câmera para habilitar a leitura do QR Code.',
      });
    }
  }, [cameraOpen]);

  return (
    <div className="absolute left-0 top-0 h-screen w-screen overflow-hidden">
      <video
        className="bg-black-pure fixed z-[1] h-full w-full overflow-hidden object-cover"
        ref={videoRef}
      />

      <div
        ref={overlayRef}
        className="!pointer-events-auto !left-0 !top-0 z-10 !h-screen !w-screen !scale-x-100 !overflow-hidden"
      >
        <OverlayInformation handleCloseCamera={handleCloseCamera} />
      </div>
    </div>
  );
};

export default QrReader;
