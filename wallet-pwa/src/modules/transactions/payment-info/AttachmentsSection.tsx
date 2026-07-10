'use client';

import { useMemo } from 'react';

import { PaperclipIcon, Plus } from 'lucide-react';
import { DateTime } from 'luxon';

import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { FileMainInfosProps, FileUpload } from '@paggo/ui/components/organisms/file-upload';

const MAX_ATTACHMENTS = 5;

type AttachmentItem = {
  createdAt: Date | string;
  id: string;
  name: string | null;
  url: string | null;
};

type Props = {
  attachments: AttachmentItem[];
  canEdit: boolean;
  description: string | null | undefined;
  paymentId: string;
  walletId: string;
};

export function AttachmentsSection({
  attachments,
  canEdit,
  description,
  paymentId,
  walletId,
}: Props) {
  const { addWalletPaymentAttachments } = useWalletPaymentService({
    id: paymentId,
    walletId,
  });

  const remainingSlots = useMemo(
    () => Math.max(0, MAX_ATTACHMENTS - attachments.length),
    [attachments.length]
  );

  const showAddButton = canEdit && remainingSlots > 0;

  const handleUpload = async (file: FileMainInfosProps) => {
    await addWalletPaymentAttachments(
      {
        description: description ?? '',
        attachments: [{ name: file.title ?? '', url: file.url }],
      },
      () => {
        toast({
          description: 'Anexos salvos com sucesso. Em instantes eles irão aparecer aqui.',
        });
      }
    );
  };

  return (
    <div className="space-y-3">
      <SemanticTypography.Label size="mid" color="gray-500">
        Anexos:
      </SemanticTypography.Label>

      {attachments.length === 0 ? (
        <SemanticTypography.Body size="big" color="gray-500">
          Não foram encontrados anexos.
        </SemanticTypography.Body>
      ) : (
        <div className="space-y-2">
          {attachments.map((item) => (
            <div key={item.id} className="flex items-center justify-between gap-x-3">
              <div className="flex min-w-0 items-center gap-x-3">
                <PaperclipIcon className="h-4 w-4 shrink-0 text-gray-500" />
                <a
                  href={
                    item.url?.startsWith('/documents-')
                      ? `https://files.paggo.ai${item.url}`
                      : item.url ?? '#'
                  }
                  target="_blank"
                  rel="noreferrer"
                  className="min-w-0 truncate"
                >
                  <SemanticTypography.Label color="gray-500" className="truncate">
                    {item.name}
                  </SemanticTypography.Label>
                </a>
              </div>
              <SemanticTypography.Caption size="big" color="gray-500" className="shrink-0">
                {(typeof item.createdAt === 'string'
                  ? DateTime.fromISO(item.createdAt)
                  : DateTime.fromJSDate(item.createdAt)
                )
                  .setLocale('pt-br')
                  .toRelative()}
              </SemanticTypography.Caption>
            </div>
          ))}
        </div>
      )}

      {showAddButton && (
        <FileUpload
          maxFiles={remainingSlots}
          renderTriggerItem={
            <Button
              icon={Plus}
              contentWidth="fill"
              hierarchy="secondary"
              label="Adicionar anexo"
            />
          }
          hideUploadedFiles
          accept={{
            'image/png': ['.png'],
            'image/x-png': ['.png'],
            'image/jpeg': ['.jpg', '.jpeg'],
            'image/gif': ['.gif'],
            'application/pdf': ['.pdf'],
          }}
          notUploadOnBucket={
            process.env.NODE_ENV === 'development' &&
            process.env.NEXT_PUBLIC_FORCE_BAAS !== '1'
          }
          onSave={handleUpload}
        />
      )}
    </div>
  );
}
