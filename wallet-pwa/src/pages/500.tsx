import { MoveLeft, RefreshCcw } from 'lucide-react';
import { useRouter } from 'next/router';

import { Button } from '@paggo/ui/components/atoms/button/index';
import Typography from '@paggo/ui/components/atoms/typography/index';
import { IllustrationPage500 } from '@paggo/ui/illustrations/IllustrationPage500';

import { EventCollection, useTracker } from '@/hooks/trackers/use-tracker';

export default function Custom500() {
  const { trackErrorPage } = useTracker(EventCollection.GENERAL_EVENTS);
  const router = useRouter();
  trackErrorPage(router.pathname);

  return (
    <div className="flex h-screen w-screen items-center justify-center p-20">
      <div className="flex h-full w-full">
        <div className="pr-30 flex h-full w-[50%] flex-col justify-center gap-4 px-10 pl-20">
          <Typography.Text size="2xl" bold>
            Não foi possível continuar...
          </Typography.Text>
          <Typography.Text size="lg">
            Tente atualizar a página. Se o problema persistir, entre em{' '}
            <a href="mailto:suporte@paggo.ai" className="font-semibold hover:underline">
              {' '}
              contato com o suporte
            </a>
            .
          </Typography.Text>
          <div className="mt-4 flex gap-4">
            <Button
              hierarchy="secondary"
              icon={MoveLeft}
              onClick={() => router.back()}
              label="Voltar"
            />
            <Button icon={RefreshCcw} label="Atualizar" onClick={() => router.reload()} />
          </div>
        </div>
        <div className="flex h-full w-[50%] items-center justify-center">
          <IllustrationPage500 className="h-[295px] w-[375px]" />
        </div>
      </div>
    </div>
  );
}
