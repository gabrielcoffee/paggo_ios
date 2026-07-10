import { useMemo, useState } from 'react';

import { useRouter } from 'next/router';

import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { LoadingAnimation } from '@paggo/ui/components/atoms/loading-animation/loading-animation';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import type { DecodeQRCodePaymentResult } from '@paggo/utils/baas';

import QrReader from '@/components/qr-code-reader/QrReader';
import { PaymentPixData } from '@/modules/payment/pix/PixPaymentData';
import { useWalletStore } from '@/providers/wallet.provider';

export function PaymentQRCode() {
  const [shouldRender, setShouldRender] = useState(true);
  const [loading, setLoading] = useState(true);
  const [fetchingQRCode, setFetchingQRCode] = useState(false);
  const [pixKey, setPixKey] = useState<string | undefined>();
  const [decodedQRCode, setDecodedQRCode] = useState<DecodeQRCodePaymentResult | undefined>();

  const { currentWallet } = useWalletStore((state) => state);
  const { decodeQRCode } = useWalletPaymentService({ walletId: currentWallet?.id });
  const router = useRouter();

  const showPixData = useMemo(
    () => !!pixKey && !!decodedQRCode && !loading && !fetchingQRCode,
    [decodedQRCode, fetchingQRCode, loading, pixKey]
  );

  const handleCloseCamera = async (goBack = false) => {
    if (goBack) router.back();
    setShouldRender(false);
    setLoading(false);
  };

  const handleResult = async (value: string) => {
    if (value?.length >= 1) {
      setFetchingQRCode(true);
      setPixKey(value);
  
      await decodeQRCode(
        { emv: value },
        (result?: DecodeQRCodePaymentResult) => {
          if (result) {
            setDecodedQRCode(result);
            setFetchingQRCode(false);
            setLoading(false);
          }
        },
        (error: any) => {
          console.log('Error decoding qrcode information :>> ', error?.message);
          toast({ description: 'Erro ao ler as informações do QRCode.' });
          router.back();
        }
      );

      return;
    }
    toast({ description: 'Erro ao ler as informações do QRCode.' });
    router.back();
  };

  return showPixData ? (
    <div className="h-full w-full overflow-x-hidden">
      <PaymentPixData
        pixKey={decodedQRCode!.key.key}
        keyDetails={decodedQRCode!.key}
        qrCodeDetails={decodedQRCode?.qrCode}
      />
    </div>
  ) : (
    <div>
      {shouldRender && (
        <div className="absolute left-0 top-0 z-[999] flex h-screen w-screen overflow-hidden">
          <div className="my-6 flex h-full w-full flex-col overflow-hidden">
            <QrReader onResult={handleResult} handleCloseCamera={handleCloseCamera} />
          </div>
        </div>
      )}

      {loading && !decodedQRCode && (
        <div className="flex flex-col items-center justify-center">
          <LoadingAnimation />
        </div>
      )}

      {fetchingQRCode && (
        <div className="absolute left-1/2 top-1/2 z-[50] -translate-x-1/2 -translate-y-1/2 overflow-x-hidden">
          <LoadingCircle className="h-10 w-10" />
        </div>
      )}
    </div>
  );
}
