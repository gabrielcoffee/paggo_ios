import { useState } from 'react';

import { ShieldCheck, LockOpen } from 'lucide-react';

import { Card } from '@paggo/fend/components/molecules/card/index';
import { useWalletService } from '@paggo/services-client/hooks';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { OtpInput } from '@paggo/ui/components/molecules/otp-input/otp-input';

import { useWalletStore } from '@/providers/wallet.provider';

interface PinValidationProps {
  onValidated: () => Promise<void>;
  onDismiss: () => void;
}

export function PinValidation({ onDismiss, onValidated }: PinValidationProps) {
  const [otp, setOtp] = useState('');
  const { currentWallet } = useWalletStore((state) => state);
  const { validateWalletUserPin } = useWalletService({
    id: currentWallet?.id,
    fetch: false,
    origin: 'user',
  });

  const onChange = (value: string) => setOtp(value);

  const verifyPin = async () => {
    try {
      await validateWalletUserPin(
        { pin: Number(otp) },
        {
          onSuccess: async (validated?: boolean) => {
            if (validated) {
              toast({
                title: 'PIN validado com sucesso. Estamos processando sua transação.',
              });

              onValidated();
              onDismiss();
            }
          },
          onError: (error: any) => {
            console.error('Error white validating PIN :>> ', error?.message);
            toast({
              title: 'Falha ao validar o PIN',
              description: 'Verifique se o mesmo está correto e tente novamente',
            });
          },
        }
      );
    } catch (error) {
      toast({ title: 'Occoreu um erro ao verificar o PIN' });
    }
  };

  return (
    <div className="bg-black-pure fixed left-0 top-0 z-[60] mb-4 mt-4 flex h-full w-full flex-col items-center p-4">
      <Card className="bg-black-pure rounded-lg">
        <Card.Header
          icon={ShieldCheck}
          title="Verificação de segurança"
          description=" Caso não lembre o seu PIN entre em contato com o suporte."
        />

        <Card.Container className="py-10">
          <OtpInput
            value={otp}
            valueLength={4}
            onValueChange={onChange}
            autofocus
            inputMode="numeric"
          />
        </Card.Container>

        <Card.Footer
          className="flex gap-4 self-center"
          buttons={[
            { label: 'Cancelar', onClick: () => onDismiss() },
            {
              label: 'Validar',
              semantic: 'magic',
              icon: LockOpen,
              alignment: 'end',
              onClick: async () => {
                await verifyPin();
              },
            },
          ]}
        />
      </Card>
    </div>
  );
}
