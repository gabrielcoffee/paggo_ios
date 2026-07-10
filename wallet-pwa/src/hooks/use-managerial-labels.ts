import { useMemo } from 'react';

import { getManagerialLabels, type ManagerialLabels } from '@paggo/constants';

import { useSession } from '@paggotech/next-auth/react';


export function useManagerialLabels(): ManagerialLabels {
  const { data: session } = useSession();
  const terminology = session?.user?.currentUserCustomer?.managerialAccountTerminology ?? null;

  return useMemo(() => getManagerialLabels(terminology), [terminology]);
}
