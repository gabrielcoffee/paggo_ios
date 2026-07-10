import { useMemo, useState } from 'react';

import { Transition } from '@headlessui/react';
import { SearchIcon, ChevronDown } from 'lucide-react';
import { useRouter } from 'next/router';

import { BACEN_INSTITUTIONS, getBankISPB, getBankStr } from '@paggo/constants';
import {
  allExists,
  capitalizeString,
  formatToCPFOrCNPJ,
  isPixQRCode,
  mapToNumeric,
  sleep,
  getAccountTypeName,
} from '@paggo/core-utils';
import { cn } from '@paggo/fend/utils';
import { useBankingInputValidation } from '@paggo/fend-utils/hooks';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { HTTP_STATUS_CODES } from '@paggo/types/api-routes';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { Select } from '@paggo/ui/components/molecules/select/select';
import { useField } from '@paggo/ui/hooks/use-field';
import { Input } from '@paggo/ui/legacy/components/atoms/input';
import { Radio, RadioGroup } from '@paggo/ui/legacy/components/atoms/radio';
import type { PixDictResult } from '@paggo/utils/baas';

import { PaymentPixData } from '@/modules/payment/pix/PixPaymentData';
import { useWalletStore } from '@/providers/wallet.provider';

import type {
  BankAccountDetails,
  BANK_ACCOUNT_TYPES as PBANK_ACCOUNT_TYPES,
} from '@prisma/client';

enum PaymentMethod {
  PIX = 'pix',
  PIX_BY_ACCOUNT = 'pix_by_account',
}

const BANK_ACCOUNT_TYPES = {
  CHECKING: 'CHECKING',
  SAVINGS: 'SAVINGS',
  PAYMENT: 'PAYMENT',
  SALARY: 'SALARY',
  INVESTMENT: 'INVESTMENT',
};

const BankAccountTypes = [
  {
    id: BANK_ACCOUNT_TYPES.CHECKING,
    value: BANK_ACCOUNT_TYPES.CHECKING,
    displayValue: getAccountTypeName(BANK_ACCOUNT_TYPES.CHECKING),
  },
  {
    id: BANK_ACCOUNT_TYPES.SAVINGS,
    value: BANK_ACCOUNT_TYPES.SAVINGS,
    displayValue: getAccountTypeName(BANK_ACCOUNT_TYPES.SAVINGS),
  },
  {
    id: BANK_ACCOUNT_TYPES.SALARY,
    value: BANK_ACCOUNT_TYPES.SALARY,
    displayValue: getAccountTypeName(BANK_ACCOUNT_TYPES.SALARY),
  },
  {
    id: BANK_ACCOUNT_TYPES.PAYMENT,
    value: BANK_ACCOUNT_TYPES.PAYMENT,
    displayValue: getAccountTypeName(BANK_ACCOUNT_TYPES.PAYMENT),
  },
  {
    id: BANK_ACCOUNT_TYPES.INVESTMENT,
    value: BANK_ACCOUNT_TYPES.INVESTMENT,
    displayValue: getAccountTypeName(BANK_ACCOUNT_TYPES.INVESTMENT),
  },
];

const availableMethods = [
  { id: PaymentMethod.PIX, label: 'Pix por Chave' },
  { id: PaymentMethod.PIX_BY_ACCOUNT, label: 'Transferência (em breve)' },
];

export function PaymentPix() {
  const [data, setData] = useState<any>();
  const [manualPixData, setManualPixData] = useState<Partial<BankAccountDetails>>({});
  const [loading, setLoading] = useState(false);
  const [animatingPixContent, setAnimatingPixContent] = useState(false);
  const [animatingPixByAccountContent, setAnimatingPixByAccountContent] = useState(false);

  const router = useRouter();
  const pixKeyField = useField('');
  const selectedPaymentMethod = useField('pix');

  const { currentWallet } = useWalletStore((state) => state);
  const { searchPixDictKey } = useWalletPaymentService({ walletId: currentWallet?.id });

  const { accountNumberValidation, branchCodeValidation, taxIdValidation } =
    useBankingInputValidation({
      accountNumber: manualPixData.accountNumber,
      bankCode: manualPixData.bankCode,
      branchCode: manualPixData.branchCode,
      taxId: manualPixData.taxId,
      accountType: manualPixData.accountType,
    });

  const isPixSelected = useMemo(
    () => selectedPaymentMethod.value === PaymentMethod.PIX,
    [selectedPaymentMethod.value]
  );

  const isPixByAccountSelected = useMemo(
    () => selectedPaymentMethod.value === PaymentMethod.PIX_BY_ACCOUNT,
    [selectedPaymentMethod.value]
  );

  const isPixByAccountFieldsValid = useMemo(() => {
    const { accountNumber, accountType, bankCode, bankCodeStr, branchCode, taxId } = manualPixData;

    const fieldsExists = allExists([
      accountNumber,
      accountType,
      bankCode,
      branchCode,
      bankCodeStr,
      taxId,
    ]);

    const fieldsValid = [
      accountNumberValidation.validationState,
      branchCodeValidation.validationState,
      taxIdValidation.validationState,
    ].every((v) => v === 'valid');

    return fieldsExists && fieldsValid;
  }, [
    manualPixData,
    accountNumberValidation.validationState,
    branchCodeValidation.validationState,
    taxIdValidation.validationState,
  ]);

  const showPixData = useMemo(() => data && !loading, [data, loading]);

  const handleGoBack = () => {
    router.back();
  };

  const handleSearchPixKey = async () => {
    if (isPixQRCode(pixKeyField.value)) {
      toast({
        title: 'Atenção',
        description:
          'Você informou um código Pix Copia e Cola, utilize o outro menu para realizar este tipo de pagamento.',
      });
      return;
    }

    if (pixKeyField.value?.length <= 3) {
      toast({
        title: 'Atenção',
        description: 'A chave digitada deve ter mais de 3 caracteres.',
      });
      return;
    }

    setLoading(true);

    searchPixDictKey(
      { pixKey: pixKeyField.value },
      (result?: PixDictResult) => {
        if (result) {
          setData({
            pixKey: result.key,
            keyDetails: {
              accountNumber: result.accountNumber,
              accountType: result.accountType,
              bankCode: result.ispb,
              branchCode: result.branchCode,
              endToEndId: result.endToEndId,
              receiverLegalName: result.name,
              receiverTaxId: result.taxId,
              type: result.type,
            },
          });
          setLoading(false);
        }
      },
      (error: any) => {
        console.log('Error while trying to search pix key dict :>> ', error?.message);

        if (error?.response?.status === HTTP_STATUS_CODES.NOT_FOUND) {
          toast({ description: 'Chave Pix não encontrada' });
          setLoading(false);
          return;
        }

        toast({ description: 'Erro ao ler as informações da chave Pix' });
        setLoading(false);
      }
    );
  };

  const handleConfirmManualPixData = async () => {
    if (!manualPixData || !isPixByAccountFieldsValid) {
      return toast({
        description: 'Dados inválidos, por favor verifique todos os dados antes de salvar',
      });
    }

    setLoading(true);
    await sleep(500);
    setLoading(false);
  };

  const updateManualPixData = (value: Partial<BankAccountDetails>) => {
    setManualPixData((prev) => ({ ...prev, ...value }));
  };

  const resetManualPixData = () => {
    updateManualPixData({
      accountNumber: undefined,
      branchCode: undefined,
      accountType: undefined,
      bankCode: undefined,
      bankCodeStr: undefined,
      taxId: undefined,
    });
  };

  return showPixData ? (
    <div className="h-full w-full overflow-x-hidden">
      <PaymentPixData pixKey={data.pixKey} keyDetails={data.keyDetails} />
    </div>
  ) : (
    <div className="flex flex-col overflow-x-hidden">
      <div className="mb-4 mt-2 flex w-full items-center gap-2 px-4 py-2">
        <Button onClick={handleGoBack} icon={ChevronDown} />

        <div className="flex w-full justify-center">
          <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
            Pagar com Pix
          </SemanticTypography.Display>
        </div>
      </div>

      <div className="flex flex-col gap-2 px-4">
        <div className="flex flex-col gap-2">
          <SemanticTypography.Title color="gray-500">
            Selecione o método de pagamento
          </SemanticTypography.Title>

          <RadioGroup
            name="payment-methods-radio-group"
            aria-label="payment-methods-radio-group"
            className="w-full"
            size="xs"
            classNames={{ wrapper: 'flex-nowrap' }}
            defaultValue={selectedPaymentMethod.value}
            value={selectedPaymentMethod.value}
            onValueChange={async (value) => {
              if (value === PaymentMethod.PIX) {
                setAnimatingPixContent(true);
                resetManualPixData();
                await sleep(300);
                setAnimatingPixContent(false);
              }

              if (value === PaymentMethod.PIX_BY_ACCOUNT) {
                setAnimatingPixByAccountContent(true);
                await sleep(300);
                setAnimatingPixByAccountContent(false);
              }

              selectedPaymentMethod.handleChange(value);
            }}
          >
            {availableMethods.map((method) => (
              <Radio
                key={method.id}
                value={method.id}
                isDisabled={method.id === PaymentMethod.PIX_BY_ACCOUNT}
                className="flex shrink-0 justify-start gap-x-2"
                classNames={{
                  control: 'bg-gray-400 text-gray-500',
                  wrapper:
                    'group-data-[hover-unchecked=true]:bg-gray-700 group-data-[checked=true]:border-gray-400 border',
                }}
              >
                <SemanticTypography color="gray-500">{method.label}</SemanticTypography>
              </Radio>
            ))}
          </RadioGroup>
        </div>

        <div className="my-4 flex flex-col gap-2">
          <Transition
            show={isPixSelected && !animatingPixByAccountContent}
            leave="transition ease-out duration-100 delay-100"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
            enter="transition ease-in duration-100 delay-100"
            enterFrom="opacity-0"
            enterTo="opacity-100"
            className="flex flex-col gap-2"
          >
            <SemanticTypography.Title color="gray-500">
              Chave Pix do destinatário
            </SemanticTypography.Title>

            <div className="flex w-full flex-col gap-2">
              <Input
                name="pix-key-input"
                aria-label="pix-key-input"
                placeholder="Digite a chave Pix"
                type="text"
                autoCapitalize="none"
                inputMode="text"
                className="text-gray-500"
                size={'md' as any}
                value={pixKeyField.value}
                onValueChange={pixKeyField.handleChange}
                isDisabled={loading}
                startContent={<SearchIcon className="h-4 w-4 shrink-0 text-gray-500" />}
                classNames={{
                  inputWrapper:
                    'border-gray-600 group-data-[focus=true]:!border-gray-500 group-data-[hover=true]:!border-gray-700',
                }}
              />

              <div className="my-4">
                <Button
                  label="Buscar chave Pix"
                  contentWidth="fill"
                  size="big"
                  semantic="neutral"
                  loading={loading}
                  onClick={handleSearchPixKey}
                />
              </div>
            </div>
          </Transition>

          <Transition
            show={isPixByAccountSelected && !animatingPixContent}
            leave="transition ease-out duration-100 delay-100"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
            enter="transition ease-in duration-100 delay-100"
            enterFrom="opacity-0"
            enterTo="opacity-100"
            className="flex flex-col gap-2"
          >
            <SemanticTypography.Title color="gray-500">
              CNPJ/CPF do Titular
            </SemanticTypography.Title>

            <div className="flex w-full flex-col gap-2">
              <Input
                name="pix-taxid-input"
                aria-label="pix-taxid-input"
                className="w-full text-gray-500"
                placeholder="00.000.000/0001-00"
                autoCapitalize="none"
                type="text"
                inputMode="numeric"
                maxLength={taxIdValidation.maxLength}
                value={taxIdValidation.mask(manualPixData?.taxId || '') || ''}
                errorMessage={taxIdValidation.errorMessage}
                validationState={taxIdValidation.validationState}
                onValueChange={(value: string) => {
                  const mappedValue = mapToNumeric(value);
                  const formattedValue = formatToCPFOrCNPJ(mappedValue);
                  updateManualPixData({ taxId: mapToNumeric(formattedValue) });
                }}
                isDisabled={loading}
                classNames={{
                  errorMessage: 'text-error-300',
                  inputWrapper: cn(
                    'border-gray-600 group-data-[focus=true]:!border-gray-500 group-data-[hover=true]:!border-gray-700',
                    taxIdValidation.validationState === 'invalid' &&
                      'border border-error-300 group-data-[focus=true]:!border-error-300'
                  ),
                }}
              />

              <SemanticTypography.Title color="gray-500">Instituição</SemanticTypography.Title>

              <div className="w-full">
                <Select
                  maxVisibleItems={11}
                  value={
                    manualPixData?.bankCode
                      ? getBankStr(manualPixData.bankCode)
                      : manualPixData?.bankCodeStr
                  }
                  key="pix-account-bank"
                  onValueChange={(value) => {
                    const valueChanged =
                      manualPixData?.bankCode !== getBankISPB(value) ||
                      manualPixData?.bankCodeStr !== value;

                    updateManualPixData({
                      ...(valueChanged && {
                        accountNumber: '',
                        branchCode: '',
                      }),
                      bankCodeStr: value,
                      bankCode: getBankISPB(value),
                    });
                  }}
                  options={BACEN_INSTITUTIONS.filter((f) => f.spiCode && f.strCode).map((v) => ({
                    value: v.strCode,
                    label: capitalizeString(`${v.strCode} - ${v.name}`),
                  }))}
                />
              </div>

              <div className="flex justify-between gap-2">
                <div className="flex w-full flex-col gap-2">
                  <SemanticTypography.Title color="gray-500">
                    Agência (sem dígito verificador)
                  </SemanticTypography.Title>

                  <Input
                    name="pix-account-branch-code"
                    aria-label="pix-account-branch-code"
                    className="w-full text-gray-500"
                    placeholder="0001"
                    autoCapitalize="none"
                    type="text"
                    inputMode="numeric"
                    isDisabled={!manualPixData?.bankCode}
                    maxLength={branchCodeValidation.maxLength}
                    value={manualPixData?.branchCode}
                    validationState={branchCodeValidation.validationState}
                    errorMessage={branchCodeValidation.errorMessage}
                    onValueChange={(value: string) => {
                      const updatedValue = mapToNumeric(value);
                      updateManualPixData({ branchCode: updatedValue });
                    }}
                    classNames={{
                      errorMessage: 'text-error-300',
                      inputWrapper: cn(
                        'border-gray-600 group-data-[focus=true]:!border-gray-500 group-data-[hover=true]:!border-gray-700',
                        taxIdValidation.validationState === 'invalid' &&
                          'border border-error-300 group-data-[focus=true]:!border-error-300'
                      ),
                    }}
                  />
                </div>

                <div className="flex w-full flex-col gap-2">
                  <SemanticTypography.Title color="gray-500">
                    Conta (com dígito verificador)
                  </SemanticTypography.Title>

                  <Input
                    name="pix-account-account-number"
                    aria-label="pix-account-account-number"
                    className="w-full text-gray-500"
                    placeholder="13456-7"
                    autoCapitalize="none"
                    type="text"
                    inputMode="numeric"
                    isDisabled={!manualPixData?.bankCode}
                    maxLength={accountNumberValidation.maxLength}
                    value={accountNumberValidation.mask(manualPixData?.accountNumber)}
                    onValueChange={(value: string) => {
                      const updatedValue = mapToNumeric(value);
                      updateManualPixData({ accountNumber: updatedValue });
                    }}
                    classNames={{
                      errorMessage: 'text-error-300',
                      inputWrapper: cn(
                        'border-gray-600 group-data-[focus=true]:!border-gray-500 group-data-[hover=true]:!border-gray-700',
                        taxIdValidation.validationState === 'invalid' &&
                          'border border-error-300 group-data-[focus=true]:!border-error-300'
                      ),
                    }}
                  />
                </div>
              </div>

              <div className="flex flex-col gap-2">
                <SemanticTypography.Title color="gray-500">Tipo de conta</SemanticTypography.Title>

                <Select
                  value={accountNumberValidation?.accountType}
                  disabled={!manualPixData?.bankCode}
                  onValueChange={(value) =>
                    updateManualPixData({ accountType: value as PBANK_ACCOUNT_TYPES })
                  }
                  placeholder="Selecione uma opção"
                  options={BankAccountTypes.map((type) => ({
                    value: type.value,
                    label: type.displayValue,
                  }))}
                />
              </div>

              <div className="my-4">
                <Button
                  label="Confirmar dados"
                  size="mid"
                  loading={loading}
                  onClick={async () => {
                    await handleConfirmManualPixData();
                  }}
                />
              </div>
            </div>
          </Transition>
        </div>
      </div>
    </div>
  );
}
