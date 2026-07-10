import { useMemo, useRef, useState } from 'react';

import { trimEnd } from 'lodash';
import { ChevronLeft } from 'lucide-react';
import { useRouter } from 'next/router';
import { useDebounce } from 'react-use';

import { isPixQRCode } from '@paggo/core-utils';
import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { useField } from '@paggo/ui/hooks/use-field';
import { Textarea } from '@paggo/ui/legacy/components/atoms/input';
import type { DecodeQRCodePaymentResult } from '@paggo/utils/baas';

import { PaymentPixData } from '@/modules/payment/pix/PixPaymentData';
import { useWalletStore } from '@/providers/wallet.provider';

export function PaymentQRByCode() {
  const [loading, setLoading] = useState(false);
  const [pixKey, setPixKey] = useState<string | undefined>();
  const [decodedQRCode, setDecodedQRCode] = useState<DecodeQRCodePaymentResult | undefined>();

  const { currentWallet } = useWalletStore((state) => state);
  const { decodeQRCode } = useWalletPaymentService({ walletId: currentWallet?.id });
  const router = useRouter();
  const pixKeyInputFieldRef = useRef(null);
  const pixKeyInputField = useField('');

  const inputValidationState = useMemo(() => {
    const input = pixKeyInputField.value;

    if (!input || input === '' || input?.length <= 3) {
      return;
    }

    const valid = isPixQRCode(pixKeyInputField.value);

    return valid ? 'valid' : 'invalid';
  }, [pixKeyInputField.value]);

  const showPixData = useMemo(
    () => !!pixKey && !!decodedQRCode && !loading,
    [decodedQRCode, loading, pixKey]
  );

  const handleGoBack = () => {
    router.back();
  };

  useDebounce(
    async () => {
      if (pixKeyInputField.value?.length > 3 && isPixQRCode(pixKeyInputField.value)) {
        setLoading(true);
        setPixKey(pixKeyInputField.value);

        if (typeof (pixKeyInputFieldRef as any).current?.blur === 'function') {
          (pixKeyInputFieldRef as any).current.blur();
        }

        await decodeQRCode(
          { emv: pixKeyInputField.value },
          (result?: DecodeQRCodePaymentResult) => {
            if (result) {
              setDecodedQRCode(result);
              setLoading(false);
            }
          },
          (error: any) => {
            const message =
              error?.response?.data?.message || 'Erro ao ler as informações do QRCode.';
            toast({ description: message });
            setLoading(false);
          }
        );
      }
    },
    1000,
    [pixKeyInputField.value]
  );

  return showPixData ? (
    <div className="h-full w-full overflow-x-hidden">
      <PaymentPixData
        pixKey={decodedQRCode!.key.key}
        keyDetails={decodedQRCode!.key}
        qrCodeDetails={decodedQRCode?.qrCode}
      />
    </div>
  ) : (
    <div className="flex flex-col overflow-x-hidden">
      <div className="mb-4 mt-2 flex w-full items-center gap-2 px-4 py-2">
        <Button onClick={handleGoBack} icon={ChevronLeft} />

        <div className="flex w-full justify-center">
          <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
            Pix Copia e Cola
          </SemanticTypography.Display>
        </div>
      </div>

      <div className="px-4">
        <Textarea
          ref={pixKeyInputFieldRef}
          className="text-gray-500"
          classNames={{ inputWrapper: 'border-gray-600 group-data-[focus=true]:!border-gray-500' }}
          name="pix-key"
          aria-label="pix-key"
          placeholder="Digite o código Pix Copia e Cola"
          errorMessage={inputValidationState === 'invalid' && 'Código inválido ou não suportado'}
          validationState={inputValidationState}
          maxRows={5}
          minRows={5}
          value={trimEnd(pixKeyInputField.value)}
          onValueChange={pixKeyInputField.handleChange}
        />
      </div>

      {loading && (
        <div className="absolute left-1/2 top-1/2 z-[50] -translate-x-1/2 -translate-y-1/2 overflow-x-hidden">
          <LoadingCircle className="h-10 w-10" />
        </div>
      )}
    </div>
  );
}
