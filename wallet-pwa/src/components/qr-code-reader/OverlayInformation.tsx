import { QrCodeIcon, X } from 'lucide-react';

import { cn } from '@paggo/fend/utils';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import { isInStandaloneMode } from '@/utils';

type OverlayInformationProps = {
  handleCloseCamera?: () => void;
};

export const OverlayInformation = ({ handleCloseCamera }: OverlayInformationProps) => (
  <div className="overflow-hidden">
    <div className={cn('absolute right-4 top-5 z-10', isInStandaloneMode() && 'top-16')}>
      <Button hierarchy="tertiary" onClick={handleCloseCamera} icon={X} />
    </div>

    <QrCodeIcon
      color="white"
      className={cn(
        'absolute left-1/2 top-16 z-10 translate-x-[-50%] opacity-50',
        isInStandaloneMode() && 'top-20'
      )}
    />

    <div
      className={cn(
        'absolute left-1/2 top-24 z-10 w-[80%] translate-x-[-50%] break-after-auto opacity-50',
        isInStandaloneMode() && 'top-28'
      )}
    >
      <SemanticTypography.Overhead color="white-pure" size="big" className="text-center">
        Aponte a câmera para o QR Code para realizar o pagamento
      </SemanticTypography.Overhead>
    </div>

    <svg
      width="100px"
      height="100px"
      viewBox="0 0 100 100"
      style={{
        backgroundColor: 'rgba(0, 0, 0, 0.4)',
        top: 0,
        left: 0,
        zIndex: 1,
        boxSizing: 'border-box',
        position: 'absolute',
        width: '100%',
        height: '100%',
      }}
    />

    <svg
      width="100px"
      height="100px"
      viewBox="0 0 100 100"
      style={{
        top: '50%',
        left: '50%',
        backgroundColor: 'rgba(255, 255, 255, 0.2)',
        zIndex: 10,
        boxSizing: 'border-box',
        position: 'absolute',
        width: '75%',
        height: '200px',
        borderRadius: '16px',
        transform: 'translate(-50%, -50%)',
      }}
    />
  </div>
);
