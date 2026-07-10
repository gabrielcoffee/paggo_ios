'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

import { Check, ChevronDown, ChevronRight, CircleCheckBig, Plus, Trash2 } from 'lucide-react';

import { formatNumberReal } from '@paggo/core-utils';
import { getMappedExceptionToast } from '@paggo/services-client/common/common';
import { useWalletPaymentService, useWalletService } from '@paggo/services-client/hooks';
import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { Input } from '@paggo/ui/legacy/components/atoms/input';

import { useManagerialLabels } from '@/hooks/use-managerial-labels';
import { isAllocationComplete } from '@/modules/transactions/allocation/helpers';

import { ManagerialPicker } from './ManagerialPicker';
import { ProjectPicker } from './ProjectPicker';

type RowDraft = {
  amountCents: number;
  costCenterCode?: string | null;
  costCenterId: string | null;
  costCenterLocked: boolean;
  costCenterName?: string | null;
  managerialAccountCode?: string | null;
  managerialAccountId: string | null;
  managerialAccountLocked: boolean;
  managerialAccountName?: string | null;
  projectId: string | null;
  projectLocked: boolean;
  projectName?: string | null;
};

type Props = {
  canEdit: boolean;
  packageId: string | undefined;
  paymentAmountCents: number;
  paymentId: string;
  walletId: string;
};

const percentToAmount = (percent: number, paymentAmountCents: number): number =>
  Math.round((Number(percent) / 100) * paymentAmountCents);

const formatNamedWithCode = (
  name?: string | null,
  code?: string | null
): string | null | undefined => {
  if (!name) return name;
  return code ? `${code} - ${name}` : name;
};

const createEmptyRow = (amountCents: number): RowDraft => ({
  projectId: null,
  costCenterId: null,
  managerialAccountId: null,
  amountCents,
  projectLocked: false,
  costCenterLocked: false,
  managerialAccountLocked: false,
});

const buildInitialRows = (
  defaults: NonNullable<
    ReturnType<typeof useWalletService>['wallet']['data']
  >['defaultAllocations'],
  saved:
    | NonNullable<
        ReturnType<typeof useWalletPaymentService>['walletPaymentAllocation']['data']
      >['allocations']
    | undefined,
  paymentAmountCents: number
): RowDraft[] => {
  if (saved && saved.length > 0) {
    const lockFields = isAllocationComplete(saved);
    return saved.map((s) => ({
      projectId: s.project?.id ?? null,
      costCenterId: s.costCenter?.id ?? null,
      managerialAccountId: s.managerialAccount?.id ?? null,
      amountCents: percentToAmount(Number(s.allocation ?? 0), paymentAmountCents),
      projectLocked: lockFields && !!s.project?.id,
      costCenterLocked: lockFields && !!s.costCenter?.id,
      managerialAccountLocked: lockFields && !!s.managerialAccount?.id,
      projectName: s.project?.name ?? null,
      costCenterName: s.costCenter?.name ?? null,
      costCenterCode: s.costCenter?.code ?? null,
      managerialAccountName: s.managerialAccount?.name ?? null,
      managerialAccountCode: s.managerialAccount?.code ?? null,
    }));
  }

  if (!defaults || defaults.length === 0) return [];

  const lockFields = isAllocationComplete(defaults);
  return defaults.map((d) => ({
    projectId: d.projectId ?? null,
    costCenterId: d.costCenterId ?? null,
    managerialAccountId: d.managerialAccountId ?? null,
    amountCents: percentToAmount(Number(d.allocation ?? 0), paymentAmountCents),
    projectLocked: lockFields && !!d.projectId,
    costCenterLocked: lockFields && !!d.costCenterId,
    managerialAccountLocked: lockFields && !!d.managerialAccountId,
    projectName: d.project?.name ?? null,
    costCenterName: d.costCenter?.name ?? null,
    costCenterCode: d.costCenter?.code ?? null,
    managerialAccountName: d.managerialAccount?.name ?? null,
    managerialAccountCode: d.managerialAccount?.code ?? null,
  }));
};

const buildOutgoingAllocations = (
  rows: RowDraft[],
  paymentAmountCents: number
): {
  allocation: number;
  projectId: string;
  costCenterId: string;
  managerialAccountId: string;
}[] => {
  if (rows.length === 0 || paymentAmountCents <= 0) return [];

  const percents = rows.map((r) => Math.round((r.amountCents / paymentAmountCents) * 100));
  const sum = percents.reduce((acc, p) => acc + p, 0);
  const remainder = 100 - sum;
  if (remainder !== 0 && percents.length > 0) {
    percents[percents.length - 1] += remainder;
  }

  return rows.map((r, i) => ({
    allocation: percents[i],
    projectId: r.projectId as string,
    costCenterId: r.costCenterId as string,
    managerialAccountId: r.managerialAccountId as string,
  }));
};

export function AllocationSection({
  canEdit,
  packageId,
  paymentAmountCents,
  paymentId,
  walletId,
}: Props) {
  const managerialLabels = useManagerialLabels();
  const { wallet } = useWalletService({ id: walletId });
  const { updateWalletPaymentAllocation, walletPaymentAllocation } = useWalletPaymentService({
    walletId,
    id: paymentId,
    fetchAllocation: true,
  });
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const [rows, setRows] = useState<RowDraft[]>([]);
  const [initialSnapshot, setInitialSnapshot] = useState<RowDraft[]>([]);
  const [picker, setPicker] = useState<{
    rowIdx: number;
    title: string;
    type: 'COST_CENTER' | 'MANAGERIAL_ACCOUNT';
  } | null>(null);
  const [projectPickerRowIdx, setProjectPickerRowIdx] = useState<number | null>(null);

  const hasInitializedRef = useRef(false);

  useEffect(() => {
    if (hasInitializedRef.current) return;
    if (wallet.isLoading || walletPaymentAllocation.isLoading) return;

    const built = buildInitialRows(
      wallet.data?.defaultAllocations ?? [],
      walletPaymentAllocation.data?.allocations,
      paymentAmountCents
    );

    const initial = built.length === 0 && canEdit ? [createEmptyRow(paymentAmountCents)] : built;

    setRows(initial);
    setInitialSnapshot(initial);
    hasInitializedRef.current = true;
  }, [
    canEdit,
    wallet.isLoading,
    walletPaymentAllocation.isLoading,
    wallet.data?.defaultAllocations,
    walletPaymentAllocation.data?.allocations,
    paymentAmountCents,
  ]);

  const isComplete = submitted || isAllocationComplete(walletPaymentAllocation.data?.allocations);

  const isAlreadyComplete = isComplete;

  const defaultsComplete =
    !isAlreadyComplete &&
    rows.length > 0 &&
    rows.every((r) => r.projectLocked && r.costCenterLocked && r.managerialAccountLocked);

  const showEditableInputs = canEdit && !isAlreadyComplete && !defaultsComplete;

  const totalAmountCents = useMemo(
    () => rows.reduce((acc, r) => acc + Number(r.amountCents ?? 0), 0),
    [rows]
  );

  const totalPercent =
    paymentAmountCents > 0 ? Math.round((totalAmountCents / paymentAmountCents) * 100) : 0;

  const allFieldsFilled = rows.every(
    (r) => !!r.projectId && !!r.costCenterId && !!r.managerialAccountId
  );

  const isReady = rows.length > 0 && allFieldsFilled && totalAmountCents === paymentAmountCents;

  const isDirty = useMemo(() => {
    if (rows.length !== initialSnapshot.length) return true;
    return rows.some((r, i) => {
      const init = initialSnapshot[i];
      if (!init) return true;
      return (
        r.projectId !== init.projectId ||
        r.costCenterId !== init.costCenterId ||
        r.managerialAccountId !== init.managerialAccountId ||
        r.amountCents !== init.amountCents
      );
    });
  }, [rows, initialSnapshot]);

  const canSave =
    canEdit && !submitting && !isAlreadyComplete && isReady && (isDirty || defaultsComplete);

  async function handleSave() {
    if (!canSave) return;

    setSubmitting(true);
    await updateWalletPaymentAllocation(
      {
        allocations: buildOutgoingAllocations(rows, paymentAmountCents),
        packageIds: [],
        packageId,
      },
      {
        onSuccess: (result) => {
          setSubmitted(true);
          if (result.status === 'updated') {
            toast({
              title: 'Alocação salva',
              description: 'A alocação foi atualizada com sucesso.',
              semantic: 'success',
            });
          } else {
            toast({
              title: 'Alocação enviada',
              description: 'A atualização foi enfileirada e será aplicada em instantes.',
              semantic: 'success',
            });
          }
        },
        onError: (error) => {
          const mapped = getMappedExceptionToast(error);
          if (mapped) {
            toast(mapped);
          } else {
            toast({
              title: 'Falha ao salvar',
              description: 'Não foi possível salvar a alocação. Tente novamente.',
              semantic: 'danger',
            });
          }
        },
      }
    );
    setSubmitting(false);
  }

  function updateRow(idx: number, patch: Partial<RowDraft>) {
    setRows((prev) => prev.map((r, i) => (i === idx ? { ...r, ...patch } : r)));
  }

  function handleAmountChange(idx: number, raw: string) {
    let val = parseInt(raw.replace(/\D/g, ''), 10);
    if (Number.isNaN(val)) val = 0;
    if (val < 0) val = 0;
    if (val > paymentAmountCents) val = paymentAmountCents;
    updateRow(idx, { amountCents: val });
  }

  function addRow() {
    if (rows.length === 0) {
      setRows([createEmptyRow(paymentAmountCents)]);
      return;
    }

    const remaining = Math.max(0, paymentAmountCents - totalAmountCents);
    setRows([...rows, createEmptyRow(remaining)]);
  }

  function removeRow(idx: number) {
    if (rows.length <= 1) return;
    const next = rows.filter((_, i) => i !== idx);
    if (next.length === 1) {
      next[0] = { ...next[0], amountCents: paymentAmountCents };
    }
    setRows(next);
  }

  if (rows.length === 0 && !canEdit) {
    return (
      <div className="space-y-2">
        <SemanticTypography.Label size="mid" color="gray-500">
          Alocação:
        </SemanticTypography.Label>
        <SemanticTypography.Body size="big" color={'gray-500'}>
          Sem alocação preenchida.
        </SemanticTypography.Body>
      </div>
    );
  }

  const showRowControls = rows.length > 1;
  const showSaveButton = canEdit && !isAlreadyComplete;
  const isSingleRow = rows.length === 1;
  const showAmountInput = showEditableInputs && !isSingleRow;

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2">
        <SemanticTypography.Label size="mid" color="gray-500">
          Alocação:
        </SemanticTypography.Label>
        {!isComplete && <Badge semantic="danger" label="Pendente" />}
      </div>

      {rows.map((row, idx) => {
        const projectDisabled = !showEditableInputs || row.projectLocked;
        const costCenterDisabled = !showEditableInputs || row.costCenterLocked || !row.projectId;
        const managerialDisabled =
          !showEditableInputs || row.managerialAccountLocked || !row.costCenterId;

        const rowPercent =
          paymentAmountCents > 0 ? Math.round((row.amountCents / paymentAmountCents) * 100) : 0;

        if (!showEditableInputs) {
          const costCenterDisplay = formatNamedWithCode(row.costCenterName, row.costCenterCode);
          const managerialDisplay = formatNamedWithCode(
            row.managerialAccountName,
            row.managerialAccountCode
          );
          return (
            <div
              key={idx}
              className="space-y-4 rounded-md border border-gray-700 bg-gray-800/40 p-4"
            >
              <ReadOnlyField label="Projeto" value={row.projectName} />
              <ReadOnlyField label="Centro de Custo" value={costCenterDisplay} />
              <ReadOnlyField label={managerialLabels.singular} value={managerialDisplay} />
              <div className="grid grid-cols-2 gap-4">
                <ReadOnlyField label="Valor" value={formatNumberReal(row.amountCents / 100)} />
                <ReadOnlyField label="Percentual" value={`${rowPercent}%`} />
              </div>
            </div>
          );
        }

        return (
          <div key={idx} className="space-y-3 rounded-md border border-gray-700 bg-gray-800/40 p-4">
            {showRowControls && (
              <div className="flex justify-end">
                <button
                  type="button"
                  onClick={() => removeRow(idx)}
                  className="text-gray-400 active:text-red-400"
                  aria-label="Remover linha"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            )}

            <FieldBlock label="Projeto">
              <DrillDownTrigger
                chevron="down"
                disabled={projectDisabled}
                placeholder="Selecionar projeto"
                value={row.projectName}
                onClick={() => setProjectPickerRowIdx(idx)}
              />
            </FieldBlock>

            <FieldBlock label="Centro de Custo">
              <DrillDownTrigger
                chevron="down"
                disabled={costCenterDisabled}
                placeholder="Selecionar centro de custo"
                value={row.costCenterName}
                onClick={() =>
                  setPicker({ rowIdx: idx, type: 'COST_CENTER', title: 'Centro de Custo' })
                }
              />
            </FieldBlock>

            <FieldBlock label={managerialLabels.singular}>
              <DrillDownTrigger
                chevron="down"
                disabled={managerialDisabled}
                placeholder={`Selecionar ${managerialLabels.singularLowercase}`}
                value={row.managerialAccountName}
                onClick={() =>
                  setPicker({
                    rowIdx: idx,
                    type: 'MANAGERIAL_ACCOUNT',
                    title: managerialLabels.singular,
                  })
                }
              />
            </FieldBlock>

            {showRowControls && (
              <div className="space-y-1">
                <SemanticTypography.Label size="mid" color="white-pure" highlight>
                  Valor
                </SemanticTypography.Label>
                <div className="flex items-center gap-3">
                  <div className="flex-1">
                    {showAmountInput ? (
                      <Input
                        classNames={{
                          base: '!p-0 !m-0',
                          input: 'text-base font-semibold lining-nums tabular-nums',
                          inputWrapper:
                            'bg-gray-900 border border-gray-700 rounded-md px-3 py-2 !h-auto',
                        }}
                        name={`row-amount-${idx}`}
                        aria-label={`row-amount-${idx}`}
                        value={formatNumberReal(row.amountCents / 100)}
                        onValueChange={(v: string) => handleAmountChange(idx, v)}
                      />
                    ) : (
                      <SemanticTypography.Body size="big" color="white-pure">
                        {formatNumberReal(row.amountCents / 100)}
                      </SemanticTypography.Body>
                    )}
                  </div>
                  <SemanticTypography.Body
                    size="big"
                    color="gray-400"
                    className="min-w-[3rem] text-right"
                  >
                    {rowPercent}%
                  </SemanticTypography.Body>
                </div>
              </div>
            )}
          </div>
        );
      })}

      {showEditableInputs && (
        <div className="flex justify-center pt-2">
          <button
            type="button"
            onClick={addRow}
            className="flex items-center gap-2 px-4 py-2 text-white"
          >
            <Plus className="h-4 w-4" />
            <SemanticTypography.Body size="big" color="white-pure">
              Adicionar linha
            </SemanticTypography.Body>
          </button>
        </div>
      )}

      {showEditableInputs && rows.length > 1 && (
        <div className="flex items-center justify-between px-1">
          <SemanticTypography.Body size="big" color="gray-400">
            Total alocado:
          </SemanticTypography.Body>
          <div className="flex items-center gap-2">
            <SemanticTypography.Body
              size="big"
              color={totalAmountCents === paymentAmountCents ? 'green-500' : 'red-500'}
              highlight
            >
              {totalPercent}% — {formatNumberReal(totalAmountCents / 100)}
            </SemanticTypography.Body>
            {totalAmountCents === paymentAmountCents && (
              <Check className="h-4 w-4 text-green-500" />
            )}
          </div>
        </div>
      )}

      {showSaveButton && (
        <Button
          icon={CircleCheckBig}
          contentWidth="fill"
          hierarchy="secondary"
          label={submitting ? 'Salvando...' : 'Salvar alocação'}
          disabled={!canSave}
          onClick={handleSave}
        />
      )}

      {picker && (
        <ManagerialPicker
          open={!!picker}
          title={picker.title}
          type={picker.type}
          projectId={
            picker.type === 'COST_CENTER' ? rows[picker.rowIdx]?.projectId ?? undefined : undefined
          }
          costCenterId={
            picker.type === 'MANAGERIAL_ACCOUNT'
              ? rows[picker.rowIdx]?.costCenterId ?? undefined
              : undefined
          }
          onOpenChange={(open) => {
            if (!open) setPicker(null);
          }}
          onSelect={(selection) => {
            const target = rows[picker.rowIdx];
            if (picker.type === 'COST_CENTER') {
              const changed = target?.costCenterId !== selection.id;
              updateRow(picker.rowIdx, {
                costCenterId: selection.id,
                costCenterName: selection.name,
                ...(changed && !target?.managerialAccountLocked
                  ? { managerialAccountId: null, managerialAccountName: null }
                  : {}),
              });
            } else {
              updateRow(picker.rowIdx, {
                managerialAccountId: selection.id,
                managerialAccountName: selection.name,
              });
            }
            setPicker(null);
          }}
        />
      )}

      {projectPickerRowIdx !== null && (
        <ProjectPicker
          open
          organizationId={wallet.data?.bankingAccount?.organizationId}
          onOpenChange={(open) => {
            if (!open) setProjectPickerRowIdx(null);
          }}
          onSelect={(selection) => {
            const target = rows[projectPickerRowIdx];
            const changed = target?.projectId !== selection.id;
            updateRow(projectPickerRowIdx, {
              projectId: selection.id,
              projectName: selection.name,
              ...(changed && !target?.costCenterLocked
                ? { costCenterId: null, costCenterName: null }
                : {}),
              ...(changed && !target?.managerialAccountLocked
                ? { managerialAccountId: null, managerialAccountName: null }
                : {}),
            });
            setProjectPickerRowIdx(null);
          }}
        />
      )}
    </div>
  );
}

function ReadOnlyField({ label, value }: { label: string; value?: string | null }) {
  return (
    <div className="space-y-1">
      <SemanticTypography.Label size="mid" color="gray-500">
        {label}
      </SemanticTypography.Label>
      <SemanticTypography.Body size="big" color={value ? 'white-pure' : 'gray-500'} highlight>
        {value ?? '—'}
      </SemanticTypography.Body>
    </div>
  );
}

function FieldBlock({ children, label }: { children: React.ReactNode; label: string }) {
  return (
    <div className="space-y-1">
      <SemanticTypography.Label size="mid" color="white-pure" highlight>
        {label}
      </SemanticTypography.Label>
      {children}
    </div>
  );
}

function DrillDownTrigger({
  chevron = 'right',
  disabled,
  onClick,
  placeholder,
  value,
}: {
  chevron?: 'right' | 'down';
  disabled?: boolean;
  onClick: () => void;
  placeholder: string;
  value?: string | null;
}) {
  const ChevronIcon = chevron === 'down' ? ChevronDown : ChevronRight;
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="flex w-full items-center justify-between rounded-md border border-gray-700 bg-gray-900 px-3 py-2.5 text-left active:bg-gray-800 disabled:opacity-70 disabled:active:bg-gray-900"
    >
      <SemanticTypography.Body size="big" color={value ? 'white-pure' : 'gray-500'}>
        {value ?? placeholder}
      </SemanticTypography.Body>
      <ChevronIcon className="h-4 w-4 shrink-0 text-gray-500" />
    </button>
  );
}
