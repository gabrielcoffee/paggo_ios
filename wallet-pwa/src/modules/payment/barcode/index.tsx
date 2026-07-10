import { useMemo, useState } from 'react';

import { Transition } from '@headlessui/react';
import { codBarras2LinhaDigitavel, validarBoleto } from '@mrmgomes/boleto-utils';
import { padEnd } from 'lodash';
import { SearchIcon, ChevronLeft } from 'lucide-react';
import { useRouter } from 'next/router';

import { mapToNumeric } from '@paggo/core-utils';
import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { BaasBankslipCheck, HTTP_STATUS_CODES } from '@paggo/types';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { useField } from '@paggo/ui/hooks/use-field';
import { Input } from '@paggo/ui/legacy/components/atoms/input';

import BarCodeScanner from '@/components/barcode-scanner/BarcodeScanner';
import { useWalletStore } from '@/providers/wallet.provider';

import { BarcodePaymentData } from './BarcodePaymentData';

export function PaymentBarcode() {
  const [showScanner, setShowScanner] = useState(false);
  const [loading, setLoading] = useState(false);
  const [bankslip, setBankslip] = useState<BaasBankslipCheck | undefined>();

  const { currentWallet } = useWalletStore((state) => state);
  const { checkBankslip } = useWalletPaymentService({ walletId: currentWallet?.id });
  const bankslipField = useField('');
  const router = useRouter();

  const showBarcodeData = useMemo(() => !!bankslip && !loading, [bankslip, loading]);

  const handleGoBack = () => {
    router.back();
  };

  const handleCloseScanner = async (goBack = false) => {
    if (goBack) router.back();
    setShowScanner(false);
    setLoading(false);
  };

  const handleCheckBankslip = async () => {
    if (!bankslipField.value) {
      toast({ description: 'Você precisa informar um código de barras antes de continuar' });
      return;
    }

    if (bankslipField.value.length < 30) {
      toast({ description: 'O código de barras precisa ter no mínimo 30 dígitos' });
      return;
    }

    let parsedBankslip = validarBoleto(bankslipField.value);

    if (!parsedBankslip.sucesso) {
      if (bankslipField.value.length < 44 && bankslipField.value.endsWith('000')) {
        parsedBankslip = validarBoleto(padEnd(bankslipField.value, 47, '0'));

        if (!parsedBankslip.sucesso) {
          toast({ description: 'O código de barras que você informou não é válido' });
          return;
        }
      } else {
        toast({ description: 'O código de barras que você informou não é válido' });
        return;
      }
    }

    setLoading(true);
    setShowScanner(false);

    const digitable = mapToNumeric(codBarras2LinhaDigitavel(parsedBankslip.codigoBarras, true));

    await checkBankslip(
      { digitable },
      (result?: BaasBankslipCheck) => {
        if (result) {
          setBankslip(result);
          setLoading(false);
        }
      },
      (error: any) => {
        console.log('Error reading bankslip data :>> ', error?.message);

        if (
          error?.response?.status === HTTP_STATUS_CODES.BAD_REQUEST &&
          error?.response?.data?.message
        ) {
          toast({ description: error?.response?.data?.message });
          setLoading(false);
          return;
        }

        toast({ description: 'Erro ao ler as informações do Código de barras.' });
        setLoading(false);
      }
    );
  };

  const handleScanResult = async (value: string) => {
    const parsedBankslip = validarBoleto(value);

    if (parsedBankslip.sucesso) {
      setLoading(true);
      setShowScanner(false);

      const digitable = mapToNumeric(codBarras2LinhaDigitavel(parsedBankslip.codigoBarras, true));

      await checkBankslip(
        { digitable },
        (result?: BaasBankslipCheck) => {
          if (result) {
            setBankslip(result);
            setLoading(false);
          }
        },
        (error: any) => {
          console.log('Error reading bankslip data :>> ', error?.message);

          if (
            error?.response?.status === HTTP_STATUS_CODES.BAD_REQUEST &&
            error?.response?.data?.message
          ) {
            toast({ description: error?.response?.data?.message });
            setLoading(false);
            return;
          }

          toast({ description: 'Erro ao ler as informações do Código de barras.' });
          setLoading(false);
        }
      );
    }
  };

  return showBarcodeData ? (
    <div className="h-full w-full overflow-x-hidden">
      <BarcodePaymentData bankslip={bankslip} />
    </div>
  ) : (
    <div className="flex flex-col overflow-x-hidden">
      <div className="mb-4 mt-2 flex w-full items-center gap-2 px-4 py-2">
        <Button onClick={handleGoBack} icon={ChevronLeft} />

        <div className="flex w-full justify-center">
          <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
            Pagar conta
          </SemanticTypography.Display>
        </div>
      </div>

      <Transition
        show={showScanner}
        enter="transform transition ease-in-out duration-500"
        enterFrom="translate-y-full"
        enterTo="translate-y-0"
        leave="transform transition ease-in-out duration-500"
        leaveFrom="translate-y-0"
        leaveTo="translate-y-full"
        className="absolute left-0 top-0 z-[999] flex h-full w-screen overflow-x-hidden"
      >
        <div className="flex h-full w-full flex-col overflow-hidden">
          <BarCodeScanner onResult={handleScanResult} handleCloseCamera={handleCloseScanner} />
        </div>
      </Transition>

      <div className="flex flex-col gap-2 overflow-x-hidden px-4">
        <SemanticTypography.Title color="gray-400">Código de Barras</SemanticTypography.Title>

        <div className="flex w-full flex-col gap-2">
          <Input
            name="barcode-input"
            aria-label="barcode-input"
            placeholder="Digite o código de barras"
            type="text"
            autoCapitalize="none"
            inputMode="numeric"
            className="text-gray-400"
            size={'md' as any}
            value={bankslipField.value}
            onValueChange={(value: string) => {
              const val = mapToNumeric(value);
              bankslipField.handleChange(val);
            }}
            isDisabled={loading}
            startContent={<SearchIcon className="h-4 w-4 shrink-0 text-gray-500" />}
            classNames={{
              inputWrapper:
                'border-gray-600 group-data-[focus=true]:!border-gray-500 group-data-[hover=true]:!border-gray-700',
            }}
          />

          <div className="my-4 flex flex-col gap-4">
            <Button
              label="Continuar"
              contentWidth="fill"
              hierarchy="secondary"
              size="mid"
              disabled={loading}
              onClick={handleCheckBankslip}
            />

            <Button
              semantic="magic"
              contentWidth="fill"
              label="Usar leitor de código de barras"
              size="mid"
              disabled={loading}
              onClick={() => setShowScanner(true)}
            />
          </div>
        </div>

        {loading && (
          <div className="flex items-center justify-center overflow-x-hidden">
            <LoadingCircle className="h-10 w-10" />
          </div>
        )}
      </div>
    </div>
  );
}
