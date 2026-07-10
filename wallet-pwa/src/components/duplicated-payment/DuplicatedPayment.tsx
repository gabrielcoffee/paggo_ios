import { isValidElement } from 'react';

import { PACKAGE_STATUS } from '@prisma/client';
import { OctagonAlertIcon } from 'lucide-react';
import { useRouter } from 'next/router';

import {
  capitalizeString,
  formatDate,
  formatNumberReal,
  getPaymentMethodName,
  mapPackageStatus,
  mapPackageStatusBadgeSemantic,
} from '@paggo/core-utils';
import { CardContainer } from '@paggo/fend/components/molecules/card/index';
import { cn } from '@paggo/fend/utils';
import { usePackageDuplicatedDetails } from '@paggo/services-client/hooks';
import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import { Button } from '@paggo/ui/components/atoms/button/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { Skeleton } from '@paggo/ui/components/atoms/skeleton/skeleton';

interface DuplicatedPaymentProps {
  duplicatedPackageId: string | null | undefined;
  handleCurrentStepToReview: () => void;
}

export function DuplicatedPayment({
  duplicatedPackageId,
  handleCurrentStepToReview,
}: DuplicatedPaymentProps) {
  const router = useRouter();
  const { isError, isLoading, pack } = usePackageDuplicatedDetails(duplicatedPackageId);

  const packageDetails = [
    {
      key: 'Valor',
      value: pack?.amount ? formatNumberReal(pack?.amount / 100) : 'Valor não encontrado',
      allowLineBreak: true,
    },
    {
      key: 'Vencimento',
      value: pack?.paymentDate
        ? formatDate(pack.paymentDate.toString(), 'dd/MM/yyyy', 'America/Sao_Paulo')
        : 'Data indefinida',
      allowLineBreak: true,
    },
    {
      key: 'Método de pagamento',
      value: pack?.paymentMethod ? getPaymentMethodName(pack?.paymentMethod) : 'Não definido',
      allowLineBreak: true,
    },
    {
      key: 'Recebedor',
      value: pack?.receiverName ? capitalizeString(pack?.receiverName) : 'Nome indisponível',
      allowLineBreak: true,
    },
    {
      key: 'Pagador',
      value: pack?.payerName ? capitalizeString(pack?.payerName) : 'Nome indisponível',
      allowLineBreak: true,
    },
    {
      key: 'Solicitante',
      value: pack?.requestName ? capitalizeString(pack?.requestName) : 'Nome indisponível',
      allowLineBreak: true,
    },
    {
      key: 'Solicitado em',
      value: pack?.paymentDate
        ? formatDate(pack.paymentDate.toString(), 'dd/MM/yyyy h:mma', 'America/Sao_Paulo')
        : 'Data indefinida',
      allowLineBreak: true,
    },
    {
      key: 'Status',
      value: pack?.status,
      allowLineBreak: true,
    },
  ];

  const handleGoBack = () => {
    router.back();
  };

  if (isError) {
    return (
      <div className="mt-9 flex flex-col gap-y-4 px-7">
        <div className="">
          <SemanticTypography.Display size="small" color="white-pure">
            Desculpe, ocorreu um erro do servidor, tente novamente.
          </SemanticTypography.Display>
        </div>
        <Button label="Voltar" onClick={handleGoBack} />
      </div>
    );
  }

  return (
    <>
      <div className="flex items-center gap-x-4 px-7">
        <OctagonAlertIcon size={16} strokeWidth={2} className="text-danger-700 shrink-0" />
        <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
          Risco de pagamento duplicado
        </SemanticTypography.Display>
      </div>
      <div className="ml-auto mr-auto pl-7 pr-7 pt-4">
        <SemanticTypography.Body size="mid" color="white-pure">
          Existe um pagamento semelhante a este no fluxo de pagamentos. Valide as informações e
          verifique se o pagamento atual é devido.
        </SemanticTypography.Body>
      </div>
      {isLoading && (
        <div className="flex flex-col gap-y-6 p-7">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
        </div>
      )}
      {!isLoading && (
        <>
          <CardContainer className="rounded-lg p-7">
            {packageDetails?.length &&
              packageDetails.map(({ allowLineBreak, key, value }, idx: number) => {
                if (!value) return null;

                return (
                  <div
                    key={idx}
                    className="flex w-full justify-between border-b border-b-gray-200 py-2.5 "
                  >
                    {isValidElement(key) ? (
                      key
                    ) : (
                      <SemanticTypography.Overhead size="small" color="white-pure">
                        {key}
                      </SemanticTypography.Overhead>
                    )}

                    {isValidElement(value) ? (
                      value
                    ) : key === 'Status' ? (
                      <Badge
                        semantic={
                          mapPackageStatusBadgeSemantic[pack?.status || PACKAGE_STATUS.NOT_PAYABLE]
                        }
                        label={mapPackageStatus[pack?.status || PACKAGE_STATUS.NOT_PAYABLE]}
                      />
                    ) : (
                      <SemanticTypography.Overhead
                        size="small"
                        color="white-pure"
                        className={cn(
                          'text-wrap break-all text-end',
                          !allowLineBreak && 'truncate'
                        )}
                      >
                        {value}
                      </SemanticTypography.Overhead>
                    )}
                  </div>
                );
              })}
          </CardContainer>
          <div className="flex w-full flex-col gap-y-3 p-7">
            <Button
              contentWidth="fill"
              label="Continuar mesmo assim"
              onClick={handleCurrentStepToReview}
            />
            <Button
              contentWidth="fill"
              hierarchy="secondary"
              label="Voltar"
              onClick={handleGoBack}
            />
          </div>
        </>
      )}
    </>
  );
}
