import useSWR from 'swr';

import { fetcher } from '@paggo/fend-utils/network';

import {
  CREATE_ERP_BILL_STATUS,
  CreateErpBillStatusResponse,
} from '@/api-services/sienge-erp/sienge-erp.dto';

const POLLING_INTERVAL_MS = 4000;

type UseErpBillStatusOptions = {
  documentNumber?: string;
  enabled?: boolean;
  paymentId: string;
  walletId: string;
};

export function useErpBillStatus({
  documentNumber,
  enabled = false,
  paymentId,
  walletId,
}: UseErpBillStatusOptions) {
  const shouldFetch = enabled && !!documentNumber;
  const key = shouldFetch
    ? `/api/wallets/${walletId}/payments/${paymentId}/erp-bill/status?documentNumber=${encodeURIComponent(
        documentNumber as string
      )}`
    : null;

  const pollingStatus = useSWR<CreateErpBillStatusResponse>(key, fetcher, {
    refreshInterval: (latestData) => {
      if (!shouldFetch) return 0;
      if (
        latestData?.operationStatus === CREATE_ERP_BILL_STATUS.SUCCESS ||
        latestData?.operationStatus === CREATE_ERP_BILL_STATUS.FAILED
      ) {
        return 0;
      }
      return POLLING_INTERVAL_MS;
    },
    revalidateOnFocus: false,
    revalidateOnReconnect: false,
    dedupingInterval: 1000,
  });

  const status = pollingStatus.data?.operationStatus ?? CREATE_ERP_BILL_STATUS.INACTIVE;

  return { pollingStatus, status };
}
