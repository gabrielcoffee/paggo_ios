import { useMemo } from 'react';

import { AxiosError } from 'axios';
import { InfoIcon, PaperclipIcon, CirclePlus, CircleCheckBig } from 'lucide-react';
import { DateTime } from 'luxon';

import { formatNumberReal } from '@paggo/core-utils';
import { cn } from '@paggo/fend/utils';
import type { WalletPaymentDetails } from '@paggo/services/prisma/payment.prisma';
import { useWalletPaymentService } from '@paggo/services-client/hooks';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import { FileMainInfosProps, FileUpload } from '@paggo/ui/components/organisms/file-upload';
import { useField } from '@paggo/ui/hooks/use-field';

import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

const maxAttachments = 5;

type TransactionDetailUploadProps = {
  walletPayment?: WalletPaymentDetails;
};

function TransactionInfo({ title, value }: { title: string; value?: string }) {
  return value ? (
    <div className="flex gap-x-2">
      <SemanticTypography.Label size="mid" color="gray-500">
        {title}
      </SemanticTypography.Label>

      <SemanticTypography.Label size="mid" color="gray-500" highlight>
        {value}
      </SemanticTypography.Label>
    </div>
  ) : null;
}

function TransactionDetailAttachments({ walletPayment }: TransactionDetailUploadProps) {
  const { amount, attachments, createdAt, description, receiverName } = walletPayment || {};
  const { navigateTo } = useNavigationStore();
  const justificationsField = useField(description ?? '');
  const { addWalletPaymentAttachments } = useWalletPaymentService({
    id: walletPayment?.id,
    walletId: walletPayment?.walletId,
  });

  const uploadedFileList = useMemo(() => {
    if (!attachments?.length) {
      return (
        <div className="flex items-center justify-between gap-x-4">
          <SemanticTypography.Body color="gray-500">
            Não foram encontrados anexos.
          </SemanticTypography.Body>
        </div>
      );
    }

    return attachments.map((item) => (
      <div key={item.id} className="flex items-center justify-between gap-x-4">
        <div className="flex items-center gap-x-4">
          <PaperclipIcon className="h-4 w-4 shrink-0 text-gray-500" />
          <div className="flex w-full justify-between">
            <a
              href={
                item?.url?.startsWith('/documents-')
                  ? `https://files.paggo.ai${item.url}`
                  : item?.url
              }
              target="_blank"
              rel="noreferrer"
              className="text-body-mid flex cursor-pointer text-gray-700"
            >
              <SemanticTypography.Label color="gray-500" className="w-[120px] truncate sm:w-fit">
                {item.name}
              </SemanticTypography.Label>
            </a>
          </div>
        </div>

        <div className="flex gap-x-1">
          <SemanticTypography.Body color="gray-500" size="mid">
            Carregado {DateTime.fromISO(item.createdAt.toString()).setLocale('pt-br').toRelative()}
          </SemanticTypography.Body>
        </div>
      </div>
    ));
  }, [attachments]);

  const attachmentsAvailable = useMemo(() => {
    if (!attachments) return maxAttachments;

    return maxAttachments - attachments.length;
  }, [attachments]);

  const showSelectAttachmentsButton = useMemo(() => {
    if (attachmentsAvailable < 1) return false;

    return true;
  }, [attachmentsAvailable]);

  const showFinishButton = useMemo(() => {
    if (showSelectAttachmentsButton) return true;

    return false;
  }, [showSelectAttachmentsButton]);

  const handleUploadedAttachments = async (file: FileMainInfosProps) => {
    const files = {
      name: file.title,
      url: file.url,
    };

    try {
      await addWalletPaymentAttachments(
        {
          description: justificationsField.value,
          attachments: [files],
        },
        () => {
          toast({
            description: 'Anexos salvos com sucesso. Em instantes eles irão aparecer aqui.',
          });
        }
      );
    } catch (error) {
      if (error instanceof AxiosError) {
        toast({
          title: 'Falha ao salvar anexos',
          description:
            error.response?.data?.message ?? 'Entre em contato com o suporte em suporte@paggo.ai.',
        });
      }
    }
  };

  if (!walletPayment) return <></>;

  return (
    <div className="flex max-w-7xl overflow-x-hidden px-4 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-4">
        <div className="flex items-center gap-x-2">
          <InfoIcon className="h-5 w-5 shrink-0 text-gray-500" />
          <SemanticTypography.Label size="mid" color="gray-500">
            Aqui você pode anexar documentos relacionados ao pagamento.
          </SemanticTypography.Label>
        </div>

        <div className="my-4 flex flex-col">
          <TransactionInfo title="Para:" value={receiverName} />
          <TransactionInfo title="Valor:" value={formatNumberReal((amount ?? 0) / 100)} />
          <TransactionInfo
            title="Data e hora:"
            value={
              createdAt
                ? DateTime.fromISO(createdAt?.toString())
                    .setLocale('pt-br')
                    .toFormat("dd/MM/yyyy 'às' hh:mm")
                : undefined
            }
          />
        </div>

        <div className="my-2 flex flex-col items-start justify-center gap-1">
          <SemanticTypography.Label size="mid" color="gray-500">
            Anexos:
          </SemanticTypography.Label>

          {uploadedFileList}
        </div>

        <div className="my-12">
          <FileUpload
            maxFiles={attachmentsAvailable}
            renderTriggerItem={
              showSelectAttachmentsButton ? (
                <div
                  className={cn(
                    'absolute bottom-0 left-1/2 my-6 flex w-[calc(100%-32px)] -translate-x-1/2 flex-col justify-center sm:w-[calc(100%-48px)] lg:w-[calc(100%-64px)]',
                    showFinishButton && 'bottom-12'
                  )}
                >
                  <Button
                    icon={CirclePlus}
                    contentWidth="fill"
                    label={
                      attachments?.length
                        ? 'Adicionar mais anexos'
                        : `Adicionar até ${attachmentsAvailable} ${
                            attachmentsAvailable > 1 ? 'anexos' : 'anexo'
                          }`
                    }
                  />
                </div>
              ) : (
                <></>
              )
            }
            hideUploadedFiles
            accept={{
              'image/x-png': ['.png'],
              'image/jpeg': ['.jpg', '.jpeg'],
              'image/gif': ['.gif'],
              'application/pdf': ['.pdf'],
            }}
            onSave={handleUploadedAttachments}
          />
        </div>

        {showFinishButton && (
          <div className="absolute bottom-0 left-1/2 my-6 flex w-[calc(100%-32px)] -translate-x-1/2 flex-col justify-center sm:w-[calc(100%-48px)] lg:w-[calc(100%-64px)]">
            <Button
              icon={CircleCheckBig}
              contentWidth="fill"
              label="Concluir"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                navigateTo({ screen: NavigationItem.HOME, replace: true });
              }}
            />
          </div>
        )}
      </div>
    </div>
  );
}

export default TransactionDetailAttachments;
