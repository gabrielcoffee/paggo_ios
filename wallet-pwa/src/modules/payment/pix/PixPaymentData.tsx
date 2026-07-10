import { useEffect, useMemo, useRef, useState } from 'react';

import { Transition } from '@headlessui/react';
import { WalletPayment, WalletPaymentIntent } from '@prisma/client';
import { sortBy, toUpper } from 'lodash';
import {
  BookmarkPlusIcon,
  WalletIcon,
  ListChecks,
  X,
  Plus,
  CircleDollarSign,
  ChevronLeft,
  ChevronDown,
  Check,
  SquareChartGantt,
  Pencil,
  CircleCheckBig,
} from 'lucide-react';
import { useRouter } from 'next/router';

import { getBankNameFromISPB } from '@paggo/constants/src/bacen-institutions';
import {
  canFormatToCPF,
  isPixQRCode,
  formatNumberReal,
  formatPaymentDate,
  formatToCPFOrCNPJ,
  sleep,
} from '@paggo/core-utils';
import { useFedexSocket, useUserMessages } from '@paggo/fedex/fedex.hook';
import { Button } from '@paggo/fend/components/atoms/button/button';
import { cn } from '@paggo/fend/utils';
import { useGeoLocation } from '@paggo/fend-utils/hooks';
import { LoadingCircle } from '@paggo/icons/LoadingCircle/index';
import type { WalletSummary } from '@paggo/services/prisma/wallet.prisma';
import { getMappedExceptionToast } from '@paggo/services-client/common/common';
import { useWalletPaymentService, useWalletService } from '@paggo/services-client/hooks';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { PackageGenericInfo } from '@paggo/ui/components/molecules/generic-info/GenericInfo';
import { useField } from '@paggo/ui/hooks/use-field';
import { Input } from '@paggo/ui/legacy/components/atoms/input';
import { RadioCard, RadioGroup } from '@paggo/ui/legacy/components/atoms/radio';

import { useSession } from '@paggotech/next-auth/react';

import { PaymentDelayed } from '@/components/animations/payment-delayed';
import { PaymentFailed } from '@/components/animations/payment-failed';
import { PaymentLoading } from '@/components/animations/payment-loading';
import { PaymentSuccessful } from '@/components/animations/payment-successful';
import { PinValidation } from '@/modules/payment/PinValidation';
import { useWalletStore } from '@/providers/wallet.provider';
import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';
import { DuplicatedPayment } from '@components/duplicated-payment/DuplicatedPayment';

type PaymentPixDataProps = {
  pixKey: string;
  keyDetails: {
    accountNumber: string;
    accountType: string;
    bankCode: string;
    branchCode: string;
    endToEndId: string;
    receiverLegalName: string;
    receiverTaxId: string;
    type: string;
  };
  qrCodeDetails?: {
    emv: string;
    type: string;
    transactionAmount: number;
    dueDate?: string | null;
    expiresIn?: string;
    merchantCity?: string;
    additionalInformation?: string;
    transactionIdentification?: string;
    debtor?: {
      debtorLegalName: string;
      debtorTaxId: string;
      city: string;
      postalCode: string;
      publicArea: string;
    };
  };
};

enum PaymentPixDataStepEnum {
  INPUT = 'input',
  REVIEW = 'review',
  DUPLICATED = 'duplicated',
}

type WalletPaymentResponse = WalletPayment & { packageId?: string };

const initialStep = PaymentPixDataStepEnum.INPUT;

export function PaymentPixData({ keyDetails, pixKey, qrCodeDetails }: PaymentPixDataProps) {
  const [showAddress, setShowAddress] = useState(false);
  const [showPaymentInfo, setShowPaymentInfo] = useState(false);
  const [currentStep, setCurrentStep] = useState<PaymentPixDataStepEnum>(initialStep);
  const [currentStateWallet, setCurrentStateWallet] = useState<WalletSummary | undefined>();

  const [paymentFailed, setPaymentFailed] = useState(false);
  const [paymentConfirmed, setPaymentConfirmed] = useState(false);
  const [paymentDelayed, setPaymentDelayed] = useState(false);
  const [sendingPayment, setSendingPayment] = useState(false);
  const [editingAmount, setEditingAmount] = useState(false);
  const [showPinValidation, setShowPinValidation] = useState(false);
  const [walletPaymentIntent, setWalletPaymentIntent] = useState<WalletPaymentIntent | undefined>();
  const [walletPayment, setWalletPayment] = useState<WalletPayment | undefined>();
  const [packageId, setPackageId] = useState<string | undefined>();

  const { currentWallet, setCurrentWallet } = useWalletStore((state) => state);
  const { wallets: walletsHook } = useWalletService({ fetch: true, origin: 'user' });
  const { createWalletPaymentIntent, payWalletIntent } = useWalletPaymentService({
    walletId: currentStateWallet?.id || currentWallet?.id,
  });
  const currentWalletField = useField(currentWallet?.id);
  const transactionAmountField = useField(qrCodeDetails?.transactionAmount || '');
  const transactionAmountFieldRef = useRef(null);
  const router = useRouter();
  const { error: locationError, location } = useGeoLocation();
  const { navigateTo } = useNavigationStore();
  const { data: session } = useSession();
  const { data: wallets } = walletsHook;

  const isQRCode = useMemo(() => isPixQRCode(pixKey), [pixKey]);
  const isReviewStep = useMemo(() => currentStep === PaymentPixDataStepEnum.REVIEW, [currentStep]);
  const isInputStep = useMemo(() => currentStep === PaymentPixDataStepEnum.INPUT, [currentStep]);
  const isDuplicatedStep = useMemo(
    () => currentStep === PaymentPixDataStepEnum.DUPLICATED,
    [currentStep]
  );
  const isTransactionAmountEditable = useMemo(
    () => isInputStep && !qrCodeDetails?.transactionAmount,
    [qrCodeDetails?.transactionAmount, isInputStep]
  );
  const sortedWallets = useMemo(
    () => sortBy(wallets, (w) => w.id !== currentWallet?.id),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [wallets]
  );

  const handleChangeWallet = (value: string) => {
    const wallet = wallets?.find((w) => w.id === value);

    if (!wallet) {
      toast({
        title: 'Atenção',
        description: 'Não foi possível obter as informações da Carteira Digital. Tente novamente.',
      });
      return;
    }

    currentWalletField.handleChange(value);
    setCurrentStateWallet(wallet);
    setCurrentWallet({
      id: wallet.id,
      name: wallet.name,
      organization: wallet.organization.legalName,
      active: wallet.active,
    });
  };
  const handleTransactionAmountChange = (value: string) => {
    let val = parseInt(value.replace(/\D/g, ''));
    if (Number.isNaN(val)) val = 0;

    transactionAmountField.handleChange(val);
  };

  const handleGoBack = () => {
    router.back();
  };

  const handleCurrentStepToReview = () => {
    setCurrentStep(PaymentPixDataStepEnum.REVIEW);
  };

  const handleBackToInput = async () => {
    await sleep(1000);
    setCurrentStep(PaymentPixDataStepEnum.INPUT);
  };

  const handleContinueToReview = async () => {
    if (!location || locationError) {
      toast({
        title: 'Atenção',
        description: 'Você precisa habilitar a sua localização antes de continuar',
      });
      return;
    }

    if (isQRCode && !qrCodeDetails) {
      toast({
        title: 'Atenção',
        description: 'Não foi possível obter as informações do qr code. Tente novamente.',
      });
      return;
    }

    if (!transactionAmountField.value && !qrCodeDetails?.transactionAmount) {
      toast({
        title: 'Atenção',
        description: 'Você precisa informar um valor antes de continuar',
      });
      return;
    }

    if (
      currentStateWallet &&
      (transactionAmountField.value > currentStateWallet.limit ||
        transactionAmountField.value > currentStateWallet.maximumLimit)
    ) {
      toast({
        title: 'Atenção',
        description:
          'O valor do pagamento é superior ao valor disponível na Carteira Digital selecionada.',
      });
      return;
    }

    try {
      const wallet = wallets?.find((w) => w.id === currentWalletField.value);

      if (!wallet) {
        toast({
          title: 'Atenção',
          description:
            'Não foi possível obter as informações da Carteira Digital. Tente novamente.',
        });
        return;
      }

      setCurrentStateWallet(wallet);
      setCurrentWallet({
        id: wallet.id,
        name: wallet.name,
        organization: wallet.organization.legalName,
        active: wallet.active,
      });

      const { latitude, longitude } = location;

      await createWalletPaymentIntent(
        {
          pixKey,
          paymentMethod: qrCodeDetails?.emv ? 'QR_CODE' : 'KEY',
          amount: transactionAmountField.value || qrCodeDetails?.transactionAmount,
          lat: latitude,
          lng: longitude,
          keyDetails: {
            ...keyDetails,
            key: pixKey,
          },
          qrCodeDetails,
          browser: navigator.userAgent,
          deviceInfo: {
            language: navigator.language,
            mediaCapabilities: navigator.mediaCapabilities,
            mediaDevices: navigator.mediaDevices,
          },
        },
        (createdWalletPaymentIntent?: WalletPaymentIntent) => {
          if (createdWalletPaymentIntent) {
            console.log('Created wallet payment intent :>> ', createdWalletPaymentIntent);

            setWalletPaymentIntent(createdWalletPaymentIntent);

            if (createdWalletPaymentIntent.potentialDuplicatedPackageId) {
              setCurrentStep(PaymentPixDataStepEnum.DUPLICATED);
            } else {
              setCurrentStep(PaymentPixDataStepEnum.REVIEW);
            }
          }
        },
        (error: any) => {
          const mapped = getMappedExceptionToast(error);
          if (mapped) {
            toast(mapped);
          } else {
            toast({
              title: 'Erro ao verificar as informações do pagamento',
              description: error.response?.data?.message || 'Tente novamente mais tarde',
            });
          }
          console.log('Error while trying to create wallet payment intent :>> ', error?.message);
        }
      );
    } catch (error: any) {
      console.log('Error creating wallet payment intent :>> ', error?.message);
    }
  };

  const sendPayment = async () => {
    if (!location || locationError) {
      toast({
        title: 'Atenção',
        description: 'Você precisa habilitar a sua localização antes de continuar',
      });
      return;
    }

    if (!walletPaymentIntent) {
      toast({
        title: 'Atenção',
        description:
          'Não é possível seguir com o pagamento nesse momento. Por favor, tente novamente mais tarde.',
      });
      return;
    }

    setSendingPayment(true);

    await payWalletIntent(
      walletPaymentIntent.id,
      (createdWalletPayment?: WalletPaymentResponse) => {
        if (createdWalletPayment) {
          setWalletPayment(createdWalletPayment);
          if (createdWalletPayment.packageId) {
            setPackageId(createdWalletPayment.packageId);
          }
        }
      },
      (error: any) => {
        const insufficientBalanceError = error.response?.data?.details?.insufficientBalance;

        setSendingPayment(false);

        if (!insufficientBalanceError) {
          setPaymentFailed(true);
        }

        toast({
          semantic: 'danger',
          description:
            error.response?.data?.message ||
            'Falha ao realizar o pagamento. Tente novamente em alguns segundos ou entre em contato com o suporte',
        });
      }
    );
  };

  const handleConfirmPayment = async () => {
    if (!location || locationError) {
      toast({
        title: 'Atenção',
        description: 'Você precisa habilitar a sua localização antes de continuar',
      });
      return;
    }

    if (!walletPaymentIntent) {
      toast({
        title: 'Atenção',
        description:
          'Não é possível seguir com o pagamento nesse momento. Por favor, tente novamente mais tarde.',
      });
      return;
    }

    const [walletUser] =
      currentStateWallet?.walletUsers.filter((wu) => wu.userId === session?.user.userId) || [];

    if (walletUser?.pin) {
      setShowPinValidation(true);
      return;
    }

    await sendPayment();
  };

  const [shouldFetchMessages, setShouldFetchMessages] = useState(false);

  const { data: messages } = useUserMessages({
    requiresAction: false,
    solved: false,
    shouldFetch: shouldFetchMessages,
  });

  useEffect(() => {
    const id = walletPayment?.id;

    messages?.forEach((message) => {
      if (id && message.event.eventType === 'WalletPaymentEvent' && message.event.data?.id === id) {
        const data = message.event.data;

        if (data.confirmed) {
          setPaymentConfirmed(true);
          setPaymentDelayed(false);
        } else {
          setPaymentFailed(true);
        }

        setSendingPayment(false);
      }
    });
  }, [messages, walletPayment?.id]);

  useFedexSocket({
    handleNewMessage: (message) => {
      const id = walletPayment?.id;

      if (id && message.event.eventType === 'WalletPaymentEvent' && message.event.data?.id === id) {
        const data = message.event.data;

        if (data.packageId) {
          setPackageId(data.packageId);
        }

        if (data.confirmed) {
          setPaymentConfirmed(true);
          setPaymentDelayed(false);
        } else {
          setPaymentFailed(true);
        }

        setSendingPayment(false);
      }
    },
  });

  useEffect(() => {
    let timeout: NodeJS.Timeout | undefined;
    let fetchMessagesTimeout: NodeJS.Timeout | undefined;

    if (sendingPayment && !paymentConfirmed && !paymentFailed) {
      timeout = setTimeout(() => {
        setPaymentDelayed(true);
      }, 30 * 1000);

      fetchMessagesTimeout = setTimeout(() => {
        setShouldFetchMessages(true);
      }, 15 * 1000);
    }

    return () => {
      if (timeout) {
        clearTimeout(timeout);
      }
      if (fetchMessagesTimeout) {
        clearTimeout(fetchMessagesTimeout);
      }
    };
  }, [paymentConfirmed, paymentFailed, sendingPayment]);

  useEffect(() => {
    if (editingAmount && transactionAmountFieldRef?.current) {
      (transactionAmountFieldRef?.current as any).focus();
    }
  }, [editingAmount]);

  if (paymentDelayed) {
    return (
      <div className="scrollbar-hide fixed left-0 top-0 mt-14 flex h-full w-full flex-col items-center gap-4 overflow-auto p-4">
        <div className="mt-20 flex">
          <PaymentDelayed width={100} />
        </div>

        <div className="flex max-w-full flex-col">
          <SemanticTypography.Display
            size="mid"
            color="white-pure"
            className="whitespace-normal break-normal text-center"
            highlight
          >
            Isso está demorando mais do que o esperado.
          </SemanticTypography.Display>
        </div>

        <div className="flex flex-col items-center justify-center gap-4">
          <SemanticTypography.Overhead size="mid" className="text-center" color="gray-500">
            Vejo o status do pagamento na tela de transações.
          </SemanticTypography.Overhead>

          <SemanticTypography.Overhead size="mid" className="text-center" color="gray-500">
            Você também pode conferir o pagamento na máquina. Caso tenha sido aprovada, você já pode
            fechar esta tela
          </SemanticTypography.Overhead>
        </div>

        <div className="absolute bottom-14 my-4 flex w-full flex-col px-4">
          <Button
            size="big"
            contentWidth="fill"
            label="Ver transações"
            icon={ListChecks}
            onClick={() => navigateTo({ screen: NavigationItem.TRANSACTIONS })}
          />
        </div>
      </div>
    );
  }

  if (paymentFailed) {
    return (
      <div className="scrollbar-hide fixed left-0 top-0 mt-14 flex h-full w-full flex-col items-center gap-4 overflow-auto p-4">
        <div className="flex w-full items-center justify-end">
          <Button icon={X} size="big" onClick={() => navigateTo({ screen: NavigationItem.HOME })} />
        </div>

        <PaymentFailed loop={false} />

        <div className="flex flex-col">
          <SemanticTypography.Display
            size="mid"
            highlight
            className="text-center"
            color="white-pure"
          >
            Pagamento falhou
          </SemanticTypography.Display>
        </div>

        <div className="flex flex-col">
          <SemanticTypography.Overhead size="big" className="text-center" color="gray-500">
            Infelizmente seu pagamento não pode ser processado nesse momento. Tente novamente mais
            tarde.
          </SemanticTypography.Overhead>
        </div>

        <div className="flex flex-col">
          <SemanticTypography.Overhead size="big" className="text-center" color="gray-500">
            Se o problema persistir, entre em contato com o suporte.
          </SemanticTypography.Overhead>
        </div>
      </div>
    );
  }

  if (paymentConfirmed) {
    return (
      <div className="scrollbar-hide fixed left-0 top-0 mt-14 flex h-full w-full flex-col items-center gap-4 overflow-auto p-4">
        <div className="flex w-full items-center justify-end">
          <Button icon={X} size="big" onClick={() => navigateTo({ screen: NavigationItem.HOME })} />
        </div>

        <PaymentSuccessful width={200} loop={false} />

        <div className="flex flex-col">
          <SemanticTypography.Display
            size="mid"
            highlight
            className="text-center"
            color="white-pure"
          >
            Pagamento enviado
          </SemanticTypography.Display>
        </div>

        <div className="flex flex-col">
          <SemanticTypography.Overhead size="big" className="text-center" color="gray-500">
            Veja os detalhes do pagamento na tela de transações.
          </SemanticTypography.Overhead>
        </div>

        <div className="absolute bottom-12 my-6 flex w-full flex-col justify-center gap-4 px-4">
          <Button
            label="Adicionar informações do pagamento"
            icon={Plus}
            contentWidth="fill"
            size="big"
            onClick={() => {
              const params = new URLSearchParams({ from: 'payment' });
              if (packageId) params.set('packageId', packageId);
              router.replace(`/transactions/${walletPayment?.id}/info?${params.toString()}`);
            }}
          />

          <Button
            label="Realizar outro pagamento"
            contentWidth="fill"
            icon={CircleDollarSign}
            size="big"
            onClick={() => router.reload()}
          />
        </div>
      </div>
    );
  }

  if (sendingPayment) {
    return (
      <div className="scrollbar-hide fixed left-0 top-0 mt-14 flex h-full w-full flex-col items-center gap-4 overflow-auto p-4">
        <div className="mt-20 flex">
          <PaymentLoading width={180} />
        </div>

        <div className="flex flex-col">
          <SemanticTypography.Display
            size="mid"
            highlight
            className="text-center"
            color="white-pure"
          >
            Processando seu pagamento
          </SemanticTypography.Display>
        </div>

        <div className="flex flex-col">
          <SemanticTypography.Overhead size="big" className="text-center" color="gray-500">
            Aguarde um pouco, não saia desta tela.
          </SemanticTypography.Overhead>

          <SemanticTypography.Overhead size="big" className="text-center" color="gray-500">
            Estamos processando o seu pagamento.
          </SemanticTypography.Overhead>
        </div>
      </div>
    );
  }

  if (isQRCode && !qrCodeDetails) {
    return (
      <div className="z-[50] flex h-screen flex-col items-center justify-center overflow-x-hidden">
        <LoadingCircle className="h-10 w-10" />
      </div>
    );
  }

  if (isDuplicatedStep) {
    return (
      <div className="z-[50] flex flex-col overflow-x-hidden">
        <div className="z-[50] flex flex-col">
          <div className="mb-4 flex items-center gap-x-2 p-4">
            <Button
              onClick={handleGoBack}
              className="!stroke-white-pure shrink-0 !bg-transparent"
              icon={ChevronLeft}
            />

            <div className={cn('flex w-full justify-center')}>
              <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
                Confirme os dados
              </SemanticTypography.Display>
            </div>
          </div>
          <DuplicatedPayment
            duplicatedPackageId={walletPaymentIntent?.potentialDuplicatedPackageId}
            handleCurrentStepToReview={handleCurrentStepToReview}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="z-[50] flex flex-col overflow-x-hidden">
      <div className="z-[50] flex flex-col">
        <div className="mb-4 flex items-center gap-x-2 p-4">
          <Button onClick={isInputStep ? handleGoBack : handleBackToInput} icon={ChevronLeft} />/
          <div className={cn('flex w-full justify-center')}>
            <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
              {isReviewStep ? 'Confirme os dados' : 'Quanto você vai pagar?'}
            </SemanticTypography.Display>
          </div>
        </div>

        <div className="flex gap-x-2 px-4">
          <SemanticTypography.Overhead size="big" color="gray-500">
            Para
          </SemanticTypography.Overhead>

          <SemanticTypography.Overhead size="big" color="white-pure" highlight>
            {toUpper(keyDetails.receiverLegalName)}
          </SemanticTypography.Overhead>
        </div>

        <div className="flex gap-x-2 px-4">
          <SemanticTypography.Overhead size="small" color="gray-500">
            {canFormatToCPF(keyDetails.receiverTaxId) ? 'CPF' : 'CNPJ'}
          </SemanticTypography.Overhead>

          <SemanticTypography.Overhead size="small" color="gray-500">
            {formatToCPFOrCNPJ(keyDetails.receiverTaxId, { mask: 'cpf' })}
          </SemanticTypography.Overhead>

          <SemanticTypography.Overhead size="small" color="gray-500">
            - {getBankNameFromISPB(keyDetails.bankCode)}
          </SemanticTypography.Overhead>
        </div>

        {isInputStep && qrCodeDetails?.debtor && (
          <div className="my-2 flex flex-col px-4">
            <Button
              onClick={() => setShowAddress(!showAddress)}
              label={showAddress ? 'Ocultar endereço' : 'Ver endereço'}
            />

            <Transition
              show={showAddress}
              enter="transition-all duration-150"
              enterFrom="opacity-0 h-0"
              enterTo="opacity-1 h-full"
              leave="transition-all duration-15 delay-600"
              leaveFrom="opacity-1 h-full"
              leaveTo="opacity-0 h-0"
              className="bg-gray-iron-900 z-[20] rounded-md px-2 py-4"
            >
              <div className="flex gap-x-2">
                <BookmarkPlusIcon className="h-4 w-4 shrink-0 text-gray-500" />
                <SemanticTypography.Caption size="mid" color="gray-500" highlight>
                  {qrCodeDetails?.debtor?.publicArea} - {qrCodeDetails?.debtor?.city}
                </SemanticTypography.Caption>
              </div>
            </Transition>
          </div>
        )}

        <div className="my-2 flex flex-col items-start px-4">
          <SemanticTypography.Overhead size="small" color="gray-500">
            Valor
          </SemanticTypography.Overhead>

          <div className="flex items-center justify-center gap-2">
            {editingAmount ? (
              <Input
                ref={transactionAmountFieldRef}
                className="text-white-pure"
                classNames={{
                  base: '!p-0 !m-0',
                  input: 'text-base font-semibold lining-nums tabular-nums !h-auto',
                  inputWrapper: 'border-none bg-gray-700 w-28 !h-auto !gap-0 !p-0 flex items-start',
                }}
                name="transaction-amount"
                aria-label="transaction-amount"
                value={formatNumberReal(transactionAmountField.value / 100)}
                onValueChange={handleTransactionAmountChange}
              />
            ) : (
              <SemanticTypography.Title size="big" color="white-pure">
                {formatNumberReal(
                  (qrCodeDetails?.transactionAmount || transactionAmountField.value) / 100
                )}
              </SemanticTypography.Title>
            )}

            {isTransactionAmountEditable && (
              <Button
                className="!stroke-white-pure shrink-0 !bg-transparent"
                icon={editingAmount ? Check : Pencil}
                onClick={() => setEditingAmount(!editingAmount)}
              />
            )}
          </div>
        </div>

        {isReviewStep && (
          <div className="my-2 flex flex-col items-start px-4">
            <SemanticTypography.Overhead size="small" color="gray-600">
              Carteira Digital selecionada
            </SemanticTypography.Overhead>

            <SemanticTypography.Overhead size="small" color="gray-600">
              {currentStateWallet?.name}
            </SemanticTypography.Overhead>
          </div>
        )}

        {qrCodeDetails && (
          <div className="my-2 flex flex-col px-4">
            <Button
              onClick={() => setShowPaymentInfo(!showPaymentInfo)}
              label="Informações do pagamento"
              icon={ChevronDown}
            />

            <Transition
              show={showPaymentInfo}
              enter="transition-all duration-150"
              enterFrom="opacity-0 h-0"
              enterTo="opacity-1 h-full"
              leave="transition-all duration-15 delay-600"
              leaveFrom="opacity-1 h-full"
              leaveTo="opacity-0 h-0"
              className="z-[20] w-full"
            >
              <div className="flex gap-x-2">
                <PackageGenericInfo
                  className="mt-2 w-full bg-gray-800 px-0 py-0 text-gray-500"
                  hideCloseButton
                  data={[
                    {
                      key: 'Identificação do pagamento',
                      value: qrCodeDetails?.transactionIdentification,
                    },
                    {
                      key: 'Vencimento',
                      value: qrCodeDetails?.dueDate
                        ? formatPaymentDate({
                            date: qrCodeDetails?.dueDate,
                            considerWorkingDays: false,
                          })
                        : undefined,
                    },
                    {
                      key: 'Expira em',
                      value: qrCodeDetails?.expiresIn
                        ? formatPaymentDate({
                            date: qrCodeDetails?.expiresIn,
                            considerWorkingDays: false,
                          })
                        : undefined,
                    },
                    {
                      key: 'Devedor',
                      value: qrCodeDetails?.debtor?.debtorLegalName,
                    },
                    {
                      key: 'Valor original',
                      value:
                        qrCodeDetails && formatNumberReal(qrCodeDetails?.transactionAmount / 100),
                    },
                    {
                      key: canFormatToCPF(qrCodeDetails?.debtor?.debtorTaxId ?? '')
                        ? 'CPF'
                        : 'CNPJ',
                      value: qrCodeDetails?.debtor?.debtorTaxId
                        ? formatToCPFOrCNPJ(qrCodeDetails?.debtor?.debtorTaxId, {
                            mask: 'cpf',
                          })
                        : undefined,
                    },
                  ]}
                />
              </div>
            </Transition>
          </div>
        )}

        {isInputStep && (
          <>
            <div className="my-2 flex w-full flex-col px-4">
              <div className="flex items-center gap-x-2">
                <WalletIcon className="h-4 w-4 shrink-0 text-gray-500" />

                <SemanticTypography.Overhead size="small" color="gray-500">
                  Carteira Digital
                </SemanticTypography.Overhead>
              </div>
            </div>

            <div className="my-2 flex w-full flex-col overflow-x-auto">
              <RadioGroup
                defaultValue={currentWalletField.value}
                onValueChange={handleChangeWallet}
                name="wallets-radio-group"
                aria-label="wallets-radio-group"
                className="flex w-full"
                classNames={{ wrapper: cn('flex-nowrap w-max px-4') }}
                orientation="horizontal"
              >
                {sortedWallets?.map((wallet) => {
                  return (
                    <RadioCard
                      value={wallet.id}
                      key={wallet.id}
                      className={cn(
                        'h-auto !w-max max-w-full border-none border-gray-800 bg-gray-800 text-gray-500 shadow-sm',
                        'hover:bg-neutral-800'
                      )}
                    >
                      <SemanticTypography.Overhead size="small" color="white-pure">
                        {wallet.name}
                      </SemanticTypography.Overhead>

                      <SemanticTypography.Overhead size="small" color="gray-500">
                        Limite disponível: {formatNumberReal(wallet.limit / 100)}
                      </SemanticTypography.Overhead>
                    </RadioCard>
                  );
                })}
              </RadioGroup>
            </div>
          </>
        )}

        {isReviewStep && (
          <div className="mx-4 my-2 flex flex-col rounded-md bg-gray-800 p-4">
            <SemanticTypography.Caption
              size="mid"
              color="white-pure"
              className="text-center"
              highlight
            >
              Confira os dados acima antes de concluir a transação. Após o pagamento, esta ação não
              pode ser desfeita.
            </SemanticTypography.Caption>
          </div>
        )}
      </div>

      <div className="absolute bottom-0 z-[50] my-4 flex w-full flex-col items-center justify-end p-4">
        <Button
          contentWidth="fill"
          hierarchy="secondary"
          label={isInputStep ? 'Continuar para revisão' : 'Confirmar pagamento'}
          icon={isInputStep ? SquareChartGantt : CircleCheckBig}
          onClick={isInputStep ? handleContinueToReview : handleConfirmPayment}
        />
      </div>

      {showPinValidation && (
        <PinValidation
          onDismiss={() => setShowPinValidation(false)}
          onValidated={() => sendPayment()}
        />
      )}
    </div>
  );
}
