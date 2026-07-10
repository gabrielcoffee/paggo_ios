'use client';

import { useEffect, useMemo, useState } from 'react';

import { ERP_TYPES, WALLET_PAYMENT_METHODS } from '@prisma/client';
import { CircleCheckBig } from 'lucide-react';
import { DateTime } from 'luxon';
import { mutate } from 'swr';

import { Input } from '@paggo/fend/components/atoms/input/input';
import { LoadingCircle } from '@paggo/icons/LoadingCircle';
import { getMappedExceptionToast } from '@paggo/services-client/common/common';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import { Button } from '@paggo/ui/components/atoms/button/index';
import { Content } from '@paggo/ui/components/atoms/content';
import { Switch } from '@paggo/ui/components/atoms/switch/switch';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { Select } from '@paggo/ui/components/molecules/select/select';

import { CREATE_ERP_BILL_STATUS } from '@/api-services/sienge-erp/sienge-erp.dto';
import { useErpBill } from '@/hooks/erp/use-erp-bill';
import { useErpBillStatus } from '@/hooks/erp/use-erp-bill-status';
import { useSiengeDocumentTypes } from '@/hooks/erp/use-sienge-document-types';
import { useSiengePaymentTypes } from '@/hooks/erp/use-sienge-payment-types';
import { isAllocationComplete } from '@/modules/transactions/allocation/helpers';

type Props = {
  canEdit: boolean;
  customerErp?: ERP_TYPES | null;
  hasExistingBill: boolean;
  packageId?: string;
  paymentConfirmed: boolean;
  paymentDate?: Date | string | null;
  paymentId: string;
  paymentMethod?: WALLET_PAYMENT_METHODS;
  walletId: string;
};

const toDateInputValue = (date?: Date | string | null): string => {
  if (!date) return DateTime.now().toFormat('yyyy-MM-dd');
  const parsed = typeof date === 'string' ? DateTime.fromISO(date) : DateTime.fromJSDate(date);
  return parsed.isValid ? parsed.toFormat('yyyy-MM-dd') : DateTime.now().toFormat('yyyy-MM-dd');
};

const getDocumentTypeLabel = (docType: { code: string; name?: string | null }): string => {
  const name = docType.name?.trim();
  return name && name !== docType.code ? `${docType.code} - ${name}` : docType.code;
};

export function ErpBillSection({
  canEdit,
  customerErp,
  hasExistingBill,
  packageId,
  paymentConfirmed,
  paymentDate,
  paymentId,
  paymentMethod,
  walletId,
}: Props) {
  const [enabled, setEnabled] = useState(false);
  const [documentType, setDocumentType] = useState('');
  const [documentNumber, setDocumentNumber] = useState('');
  const [paymentTypeErpId, setPaymentTypeErpId] = useState('');
  const [documentDate, setDocumentDate] = useState(() => toDateInputValue(paymentDate));
  const [submitting, setSubmitting] = useState(false);
  const [startPolling, setStartPolling] = useState(false);
  const [submittedDocumentNumber, setSubmittedDocumentNumber] = useState('');

  const { payment, walletPaymentAllocation } = useWalletPaymentService({
    walletId,
    id: paymentId,
    fetchAllocation: true,
  });

  const allocationComplete = isAllocationComplete(walletPaymentAllocation.data?.allocations);

  const { siengeDocumentTypesData } = useSiengeDocumentTypes({ shouldFetch: enabled });
  const { defaultPaymentType, siengePaymentTypesData, sortedPaymentTypes } =
    useSiengePaymentTypes({ paymentMethod, shouldFetch: enabled });

  const { createErpBill } = useErpBill({ paymentId, walletId });
  const { pollingStatus, status: operationStatus } = useErpBillStatus({
    enabled: startPolling,
    documentNumber: submittedDocumentNumber,
    paymentId,
    walletId,
  });

  const pollingError = pollingStatus.error;

  const maxDocumentDate = toDateInputValue(paymentDate);

  useEffect(() => {
    if (defaultPaymentType && !paymentTypeErpId) {
      setPaymentTypeErpId(String(defaultPaymentType.erpId));
    }
  }, [defaultPaymentType, paymentTypeErpId]);

  useEffect(() => {
    if (operationStatus === CREATE_ERP_BILL_STATUS.SUCCESS) {
      setStartPolling(false);
      payment.mutate();
      mutate(`/api/wallets/${walletId}/payments/${paymentId}/erp-bill`);
    }
    if (operationStatus === CREATE_ERP_BILL_STATUS.FAILED || pollingError) {
      setStartPolling(false);
    }
  }, [operationStatus, payment, pollingError, paymentId, walletId]);

  const documentTypeOptions = useMemo(
    () =>
      (siengeDocumentTypesData.data ?? []).map((docType) => ({
        value: docType.code,
        label: getDocumentTypeLabel(docType),
      })),
    [siengeDocumentTypesData.data]
  );

  const paymentTypeOptions = useMemo(
    () =>
      sortedPaymentTypes.map((paymentType) => ({
        value: String(paymentType.erpId),
        label: `${paymentType.erpId} - ${paymentType.name}`,
        aiSuggestion: paymentType.isSuggested,
      })),
    [sortedPaymentTypes]
  );

  const shouldRender =
    canEdit &&
    customerErp === ERP_TYPES.SIENGE &&
    paymentConfirmed &&
    !hasExistingBill &&
    !!packageId;

  if (!shouldRender) return null;

  const isProcessing =
    !pollingError &&
    (operationStatus === CREATE_ERP_BILL_STATUS.PROCESSING ||
      (startPolling && operationStatus === CREATE_ERP_BILL_STATUS.INACTIVE));

  const isSuccess = operationStatus === CREATE_ERP_BILL_STATUS.SUCCESS;
  const isFailed = operationStatus === CREATE_ERP_BILL_STATUS.FAILED || !!pollingError;

  const isFormValid =
    !!documentType && documentNumber.trim().length > 0 && !!paymentTypeErpId && !!documentDate;

  async function handleSubmit() {
    if (submitting) return;

    if (!allocationComplete) {
      toast({
        title: 'Alocação pendente',
        description: 'Preencha a alocação do pagamento antes de criar o título.',
        semantic: 'warning',
      });
      return;
    }

    if (!isFormValid) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Preencha todos os campos para criar o título.',
        semantic: 'warning',
      });
      return;
    }

    const selectedDate = DateTime.fromISO(documentDate);
    const paymentLimit = DateTime.fromISO(maxDocumentDate).endOf('day');
    if (selectedDate > paymentLimit) {
      toast({
        title: 'Data inválida',
        description: 'A data do documento não pode ser depois da data do pagamento.',
        semantic: 'danger',
      });
      return;
    }

    setSubmitting(true);
    await createErpBill(
      {
        documentType,
        documentNumber: documentNumber.trim(),
        issuedDate: selectedDate.toISO() ?? documentDate,
        paymentTypeId: Number(paymentTypeErpId),
      },
      {
        onSuccess: () => {
          setSubmittedDocumentNumber(documentNumber.trim());
          setStartPolling(true);
          toast({ title: 'Criação de título iniciada', semantic: 'success' });
        },
        onError: (error: unknown) => {
          const mapped = getMappedExceptionToast(error);
          toast(
            mapped ?? {
              title: 'Falha ao criar título',
              description: 'Não foi possível criar o título no Sienge. Tente novamente.',
              semantic: 'danger',
            }
          );
        },
      }
    );
    setSubmitting(false);
  }

  function handleRetry() {
    setStartPolling(false);
    setSubmittedDocumentNumber('');
  }

  return (
    <div className="space-y-4 border-t border-gray-700 pt-6">
      <div className="flex items-center justify-between gap-3">
        <Content.Body size="mid" value="Criar título no Sienge" highlight />
        <Switch
          active={enabled}
          disabled={isProcessing || isSuccess}
          onActiveChange={setEnabled}
        />
      </div>

      {enabled && !allocationComplete && (
        <div className="flex items-center gap-3 rounded-md border border-gray-700 bg-gray-800/40 p-4">
          <Badge semantic="warning" label="Alocação pendente" />
          <Content.Body size="big" value="Preencha a alocação acima antes de criar o título." />
        </div>
      )}

      {enabled && allocationComplete && isSuccess && (
        <div className="flex items-center gap-3 rounded-md border border-gray-700 bg-gray-800/40 p-4">
          <Badge semantic="success" label="Título criado" />
          <Content.Body size="big" value="Título criado com sucesso no Sienge." />
        </div>
      )}

      {enabled && allocationComplete && isProcessing && (
        <div className="flex items-center gap-3 rounded-md border border-gray-700 bg-gray-800/40 p-4">
          <LoadingCircle className="text-white-pure h-5 w-5" />
          <Content.Body size="big" value="Criando título no Sienge..." />
        </div>
      )}

      {enabled && allocationComplete && !isProcessing && !isSuccess && (
        <div className="space-y-4">
          {isFailed && (
            <div className="flex items-center gap-3 rounded-md border border-gray-700 bg-gray-800/40 p-4">
              <Badge semantic="danger" label="Falha" />
              <Content.Body
                size="big"
                value="Não foi possível criar o título. Revise os dados e tente novamente."
              />
            </div>
          )}

          <Select
            label="Tipo de documento"
            placeholder="Selecione o tipo de documento"
            value={documentType}
            onValueChange={setDocumentType}
            options={documentTypeOptions}
            loading={siengeDocumentTypesData.isLoading}
            required
          />

          <Input
            label="Número do documento"
            placeholder="Insira o número do documento"
            type="number"
            value={documentNumber}
            onValueChange={(value: string) => setDocumentNumber(value)}
            required
          />

          <Select
            label="Tipo de pagamento"
            placeholder="Selecione o tipo de pagamento"
            value={paymentTypeErpId}
            onValueChange={setPaymentTypeErpId}
            options={paymentTypeOptions}
            loading={siengePaymentTypesData.isLoading}
            required
          />

          <Input
            label="Data do documento"
            type="date"
            value={documentDate}
            max={maxDocumentDate}
            onValueChange={(value: string) => setDocumentDate(value)}
            required
          />

          <Button
            icon={CircleCheckBig}
            contentWidth="fill"
            hierarchy="secondary"
            label={submitting ? 'Criando...' : 'Criar título'}
            disabled={submitting || !isFormValid}
            onClick={handleSubmit}
          />

          {isFailed && (
            <Button
              contentWidth="fill"
              hierarchy="tertiary"
              label="Tentar novamente"
              onClick={handleRetry}
            />
          )}
        </div>
      )}
    </div>
  );
}
