import useSWR from 'swr';

import { axiosInstance } from '@paggo/core-utils';
import { fetcher } from '@paggo/fend-utils/network';
import { defineServerAction } from '@paggo/services-client/common/common';

import {
  CreateErpBillRequestDto,
  GetErpBillResponse,
} from '@/api-services/sienge-erp/sienge-erp.dto';

export function useErpBill({ paymentId, walletId }: { paymentId: string; walletId: string }) {
  const baseUrl = `/api/wallets/${walletId}/payments/${paymentId}/erp-bill`;

  const createErpBill = defineServerAction(async (data: CreateErpBillRequestDto) => {
    const response = await axiosInstance.post(baseUrl, data);
    return response.data;
  });

  return { createErpBill };
}

type UseErpBillReferenceOptions = {
  enabled?: boolean;
  paymentId: string;
  walletId: string;
};

export function useErpBillReference({
  enabled = true,
  paymentId,
  walletId,
}: UseErpBillReferenceOptions) {
  const key =
    enabled && walletId && paymentId
      ? `/api/wallets/${walletId}/payments/${paymentId}/erp-bill`
      : null;

  const { data, error, isLoading, mutate } = useSWR<GetErpBillResponse>(key, fetcher, {
    revalidateOnFocus: false,
  });

  return { bill: data?.bill ?? null, error, isLoading, mutate };
}
