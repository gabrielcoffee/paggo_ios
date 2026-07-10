'use client';

import { useState } from 'react';

import { motion } from 'framer-motion';
import Image from 'next/image';
import { mutate } from 'swr';

import { capitalizeString } from '@paggo/core-utils';
import { toast } from '@paggo/ui/components/atoms/toast/toast';
import Typography from '@paggo/ui/components/atoms/typography/index';
import { Select } from '@paggo/ui/components/molecules/select/select';
import { LoadingDots } from '@paggo/ui/components/temp/shared/icons';
import { Popover, PopoverContent, PopoverTrigger } from '@paggo/ui/legacy/components/atoms/popover';

import { SessionUser } from '@paggotech/next-auth';
import { signOut } from '@paggotech/next-auth/react';

import { useSessionCustomer } from '@hooks/session/use-session-customer.hook';

const FADE_IN_ANIMATION_SETTINGS = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  transition: { duration: 0.2 },
};

export default function UserInfo(user: SessionUser) {
  const [openPopover, setOpenPopover] = useState(false);
  const [loading, setLoading] = useState(false);

  const { updateSessioCustomer } = useSessionCustomer();

  return (
    <motion.div className="inline-blocktext-left relative h-6 w-6" {...FADE_IN_ANIMATION_SETTINGS}>
      <Popover open={openPopover} onOpenChange={setOpenPopover}>
        <PopoverContent collisionPadding={8} className="rounded-xl bg-gray-800 p-0 sm:w-64">
          <div className="my-2 flex w-full flex-col pb-0 pt-3">
            <div className="mb-3 flex flex-col justify-between px-5">
              <Typography.Text aria-hidden="true" medium color="gray-500">
                {user.name}
              </Typography.Text>
              <Typography.Text aria-hidden="true" size="xs" color="gray-500">
                {user.email}
              </Typography.Text>
            </div>
            {loading && (
              <div className="my-1 flex w-full flex-col space-y-2 px-5">
                <LoadingDots color="#fff" />
              </div>
            )}
            {!loading && user?.userCustomers?.length > 1 && user?.customerId && (
              <Select
                onValueChange={async (val) => {
                  setLoading(true);
                  try {
                    await updateSessioCustomer({ customerId: val });
                    // Clear all SWR caches so no data from the previous
                    // customer leaks into the new session, then hard-reload
                    // to also reset client stores for the new customer.
                    await mutate(() => true, undefined, { revalidate: false });
                    window.location.assign('/');
                  } catch (error) {
                    toast({ description: 'Falha ao alterar cliente' });
                    setLoading(false);
                  }
                }}
                value={user?.customerId}
                options={user.userCustomers.map((v) => ({
                  value: v.customerId,
                  label: capitalizeString(v.customerLegalName),
                }))}
              />
            )}
            <div>
              <button
                className="text-gray-true-400 focus-visible:outline-primary-600 hover:text-gray-true-400 hover:bg-gray-true-800  flex w-full items-center justify-start gap-x-3 px-6 py-2 text-sm font-normal leading-6 transition-colors"
                onClick={() => signOut()}
              >
                <Typography.Text size="xs"> Sair </Typography.Text>
              </button>
            </div>
          </div>
        </PopoverContent>

        <PopoverTrigger asChild>
          <button
            onClick={() => setOpenPopover(!openPopover)}
            className="border-gray-true-600 hover:border-gray-true-500 h-6 w-6 rounded-full border-[0.5px]"
          >
            <Image
              className="rounded-full bg-gray-50"
              src={
                user.image || `https://api.dicebear.com/5.x/initials/png?seed=${user.name}&scale=75`
              }
              width={22}
              height={22}
              alt="user-image"
            />
          </button>
        </PopoverTrigger>
      </Popover>
    </motion.div>
  );
}
