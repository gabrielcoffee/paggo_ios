import useSWR from 'swr';

import { fetcher } from '@paggo/fend-utils/network';

import { SiengeDocumentType } from '@/api-services/sienge-erp/sienge-erp.dto';

export function useSiengeDocumentTypes({ shouldFetch = true }: { shouldFetch?: boolean } = {}) {
  const url = shouldFetch ? '/api/sienge/document-types' : null;

  const siengeDocumentTypesData = useSWR<SiengeDocumentType[]>(url, fetcher, {
    shouldRetryOnError: false,
    revalidateOnFocus: false,
  });

  return { siengeDocumentTypesData };
}
