'use client';

import { cn } from '@paggo/fend/utils';
import { openInNewTab } from '@paggo/fend-utils/dom';
import PaggoLogoLight from '@paggo/icons/PaggoLogoLight/index';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import LoginOptions from '@paggo/ui/components/pages/unauthenticated/components/LoginOptions';

import { isInStandaloneMode } from '@/utils';

export function Unauthenticated() {
  return (
    <div
      className={cn(
        'bg-gray-25 flex h-screen w-screen items-center justify-center px-4 sm:px-0',
        isInStandaloneMode() && 'h-full'
      )}
    >
      <div className="flex h-full w-full flex-col">
        <div className="flex w-full justify-start">
          <PaggoLogoLight />
        </div>
        <LoginOptions />
        <div className="flex w-full items-center justify-center py-10">
          <div className="flex flex-col items-center justify-center gap-x-2 py-4">
            <button
              type="button"
              className="m-0 border-none p-0"
              onClick={() => {
                openInNewTab('https://www.paggo.com.br/terms-conditions');
              }}
            >
              <SemanticTypography
                color="gray-600"
                size="small"
                variant="title"
                className="hover:cursor-pointer hover:underline"
              >
                Termos e Condições
              </SemanticTypography>
            </button>

            <SemanticTypography size="small" variant="body" color="gray-600">
              Copyright @ 2025 Paggo Tecnologia LTDA.
            </SemanticTypography>
          </div>
        </div>
      </div>
    </div>
  );
}
