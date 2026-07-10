import { useEffect } from 'react';

import { useRouter } from 'next/router';

import { Button } from '@paggo/ui/components/atoms/button/index';
import { IllustrationPage404 } from '@paggo/ui/illustrations/IllustrationPage404';

import { signOut, useSession } from '@paggotech/next-auth/react';

export default function SignOut() {
  const router = useRouter();
  const sessionResult = useSession();
  const status = sessionResult?.status;
  useEffect(() => {
    if (status === 'unauthenticated' && router.asPath !== '/') {
      router.push('/');
    }
  }, [status, router]);

  return (
    <div className="flex h-screen w-screen items-center justify-center p-20">
      <div className="flex h-full w-full">
        <div className="pr-30 flex h-full w-[50%] flex-col justify-center gap-4 px-10 pl-20">
          <div className="mt-4 flex gap-4">
            <Button
              onClick={() => {
                signOut({ redirect: true });
              }}
              label="Deslogar"
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
