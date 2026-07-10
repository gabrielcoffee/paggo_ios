import { cloneElement } from 'react';

import { ChevronRightIcon, CopyIcon, QrCodeIcon } from 'lucide-react';

import { cn } from '@paggo/fend/utils';
import { Barcode } from '@paggo/icons/Barcode';
import { Pix as PixIcon } from '@paggo/icons/Pix';
import { Badge } from '@paggo/ui/components/atoms/badge/badge';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

import { useNavigationStore } from '@/stores/navigation.store';
import { NavigationItem } from '@/types/bottom-navigation.interface';

type LinkRowProps = {
  title: string;
  description: string;
  onClick?: () => void;
  icon: React.ReactElement;
  disabled?: boolean;
  tagSoon?: boolean;
  tagNew?: boolean;
};

function LinkRow({ description, disabled, icon, onClick, tagNew, tagSoon, title }: LinkRowProps) {
  return (
    <a
      className="cursor-pointer"
      onClick={(e) => {
        e.stopPropagation();
        if (disabled) return;
        onClick && onClick();
      }}
    >
      <div className="border-gray-iron-600 flex w-full items-center justify-center border-b py-4">
        <div className="flex w-full items-center gap-x-4 gap-y-2">
          {icon &&
            cloneElement(icon, {
              ...icon.props,
              className: cn(icon.props?.className, disabled && 'text-gray-700'),
            })}

          <div className="flex flex-col">
            <div className="flex items-center gap-x-4">
              <SemanticTypography.Title
                size="big"
                color={disabled ? 'gray-700' : 'white-pure'}
                className="font-medium"
              >
                {title}
              </SemanticTypography.Title>

              {tagSoon && <Badge semantic="info" label="em breve" />}
              {tagNew && <Badge semantic="magic" label="novo" />}
            </div>

            <SemanticTypography.Label size="mid" color={disabled ? 'gray-700' : 'gray-500'}>
              {description}
            </SemanticTypography.Label>
          </div>
        </div>

        <ChevronRightIcon className="h-5 w-5 shrink-0 stroke-1" />
      </div>
    </a>
  );
}

export default function PaymentContent() {
  const { navigateTo } = useNavigationStore();

  return (
    <div className="flex flex-col overflow-x-hidden">
      <div className="my-4 gap-2 px-4 py-2">
        <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
          Escolha como pagar
        </SemanticTypography.Display>
      </div>

      <div className="px-4">
        <LinkRow
          title="Código QR"
          description="Escaneie o código e pague suas contas"
          icon={<QrCodeIcon className="text-white-pure h-4 w-4 shrink-0" />}
          onClick={() => navigateTo({ screen: NavigationItem.PAYMENT_QR })}
        />
        <LinkRow
          title="Pix Copia e Cola"
          description="Cole o código copiado para pagar"
          icon={<CopyIcon className="text-white-pure h-4 w-4 shrink-0" />}
          onClick={() => navigateTo({ screen: NavigationItem.PAYMENT_QR_BY_CODE })}
        />
        <LinkRow
          title="Pix"
          description="Selecione ou digite os dados para pagar"
          icon={<PixIcon className="text-white-pure h-4 w-4 shrink-0 stroke-1" />}
          onClick={() => navigateTo({ screen: NavigationItem.PAYMENT_PIX })}
        />
        <LinkRow
          title="Código de barras"
          description="Escaneie ou digite o código de barras para pagar"
          icon={<Barcode className="text-white-pure h-4 w-4 shrink-0 stroke-1" />}
          onClick={() => navigateTo({ screen: NavigationItem.PAYMENT_BANKSLIP })}
          tagNew
        />
      </div>
    </div>
  );
}
