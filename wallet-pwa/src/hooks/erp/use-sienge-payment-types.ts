import { WALLET_PAYMENT_METHODS } from '@prisma/client';
import useSWR from 'swr';

import { fetcher } from '@paggo/fend-utils/network';

import { SiengePaymentTypeOption } from '@/api-services/sienge-erp/sienge-erp.dto';

type UseSiengePaymentTypesOptions = {
  paymentMethod?: WALLET_PAYMENT_METHODS;
  shouldFetch?: boolean;
};

export function useSiengePaymentTypes({
  paymentMethod,
  shouldFetch = true,
}: UseSiengePaymentTypesOptions) {
  const url = paymentMethod
    ? `/api/sienge/payment-types?paymentMethod=${paymentMethod}`
    : '/api/sienge/payment-types';

  const siengePaymentTypesData = useSWR<SiengePaymentTypeOption[]>(
    shouldFetch ? url : null,
    fetcher,
    { revalidateOnFocus: false }
  );

  const sortedPaymentTypes = siengePaymentTypesData.data ?? [];
  const defaultPaymentType = sortedPaymentTypes.find((paymentType) => paymentType.isDefault);

  return { defaultPaymentType, siengePaymentTypesData, sortedPaymentTypes };
}
