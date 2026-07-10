import { MoveLeft } from 'lucide-react';
import { useRouter } from 'next/router';

import { Button } from '@paggo/ui/components/atoms/button/index';
import Typography from '@paggo/ui/components/atoms/typography/index';
import { IllustrationPage404 } from '@paggo/ui/illustrations/IllustrationPage404';

export default function Custom404() {
  const router = useRouter();
  return (
    <div className="flex h-screen w-screen items-center justify-center p-4">
      <div className="flex h-full w-full flex-col items-center">
        <div className="flex w-4/5 items-center self-center">
          <IllustrationPage404 className="h-[295px] w-[375px]" />
        </div>

        <div className="flex w-full flex-col items-center justify-center gap-4">
          <Typography.Text size="2xl" bold>
            Não encontramos essa página...
          </Typography.Text>

          <div className="flex flex-col items-center justify-center">
            <Typography.Text size="lg" className="text-center">
              Tente voltar ou ir para o início. Se o problema persistir, entre em{' '}
              <a href="mailto:suporte@paggo.ai">
                <span className="font-semibold hover:underline">contato com o suporte.</span>
              </a>
            </Typography.Text>
          </div>

          <div className="mt-10 flex justify-center gap-4">
            <Button
              hierarchy="secondary"
              icon={MoveLeft}
              label="Voltar"
              onClick={() => router.back()}
            />

            <Button
              label="Ir para o início"
              onClick={async () => {
                if (router.asPath === '/') return;
                await router.push('/');
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
