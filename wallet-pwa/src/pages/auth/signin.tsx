import { useRouter } from 'next/router';

import { Button } from '@paggo/ui/components/atoms/button/index';
import Typography from '@paggo/ui/components/atoms/typography/index';
import { IllustrationPage404 } from '@paggo/ui/illustrations/IllustrationPage404';

export default function SignIn() {
  const router = useRouter();
  return (
    <div className="flex h-screen w-screen items-center justify-center p-20">
      <div className="flex h-full w-full">
        <div className="pr-30 flex h-full w-[50%] flex-col justify-center gap-4 px-10 pl-20">
          <Typography.Text size="2xl" bold>
            Não foi possível fazer login
          </Typography.Text>
          <Typography.Text size="lg">
            Confira se você está usando o mesmo provedor que usou para se cadastrar ou se suas
            credenciais estão corretas. Se o problema persistir, entre em{' '}
            <a href="mailto:suporte@paggo.ai" className="font-semibold hover:underline">
              {' '}
              contato com o suporte
            </a>
            .
          </Typography.Text>
          <div className="mt-4 flex gap-4">
            <Button
              label="  Retornar para login"
              onClick={async () => {
                if (router.asPath === '/') return;
                await router.push('/');
              }}
            />
          </div>
        </div>
        <div className="flex h-full w-[50%] items-center justify-center">
          <IllustrationPage404 className="h-[295px] w-[375px]" />
        </div>
      </div>
    </div>
  );
}
