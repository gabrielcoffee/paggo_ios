'use client';

import { useEffect, useState } from 'react';

import { CircleCheckBig } from 'lucide-react';

import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { Textarea } from '@paggo/ui/legacy/components/atoms/input';

type Props = {
  canEdit: boolean;
  initialDescription: string | null | undefined;
  paymentId: string;
  walletId: string;
};

export function DescriptionSection({
  canEdit,
  initialDescription,
  paymentId,
  walletId,
}: Props) {
  const { addWalletPaymentDescription } = useWalletPaymentService({
    id: paymentId,
    walletId,
  });

  const [description, setDescription] = useState<string>(initialDescription ?? '');
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    setDescription(initialDescription ?? '');
  }, [initialDescription]);

  const initial = (initialDescription ?? '').trim();
  const hasPersistedValue = initial.length > 0;
  const isLocked = hasPersistedValue || submitted;
  const isDirty = canEdit && !isLocked && description.trim() !== initial;
  const canSave = canEdit && !isLocked && !submitting && isDirty;

  async function handleSave() {
    if (!canSave) return;

    setSubmitting(true);
    try {
      await addWalletPaymentDescription(
        { description },
        {
          onSuccess: () => {
            setSubmitted(true);
            toast({
              title: 'Justificativa salva',
              description: 'A justificativa foi registrada.',
              semantic: 'success',
            });
          },
          onError: () => {
            toast({
              title: 'Falha ao salvar',
              description: 'Não foi possível salvar a justificativa. Tente novamente.',
              semantic: 'danger',
            });
          },
        }
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (isLocked || !canEdit) {
    const displayText = (description || initial).trim();
    return (
      <div className="space-y-2">
        <SemanticTypography.Label size="mid" color="gray-500">
          Justificativa:
        </SemanticTypography.Label>
        <SemanticTypography.Body
          size="big"
          color={displayText ? 'white-pure' : 'gray-500'}
        >
          {displayText || 'Sem justificativa.'}
        </SemanticTypography.Body>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <SemanticTypography.Label size="mid" color="gray-500">
        Justificativa:
      </SemanticTypography.Label>
      <Textarea
        name="justificativa"
        aria-label="justificativa"
        className="text-white-pure"
        classNames={{
          inputWrapper:
            'bg-gray-800/40 border border-gray-700 group-data-[focus=true]:!border-gray-500',
          input: 'text-white-pure placeholder:text-gray-500',
        }}
        placeholder="Digite uma justificativa para este pagamento"
        maxRows={4}
        minRows={4}
        value={description}
        onValueChange={setDescription}
      />
      <Button
        icon={CircleCheckBig}
        contentWidth="fill"
        hierarchy="secondary"
        label={submitting ? 'Salvando...' : 'Salvar justificativa'}
        disabled={!canSave}
        onClick={handleSave}
      />
    </div>
  );
}
