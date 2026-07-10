import { useCallback, useMemo } from 'react';

import { MANAGERIAL_TYPES } from '@prisma/client';
import useSWRInfinite, { SWRInfiniteKeyLoader } from 'swr/infinite';

import { fetcher } from '@paggo/fend-utils/network';
import type { PaginatedCursorResponse } from '@paggo/types/api-routes';

export type ProjectOption = {
  id: string;
  name: string;
};

export type ManagerialOption = {
  id: string;
  name: string;
  code: string | null;
};

type UseProjectOptionsArgs = {
  enabled: boolean;
  organizationId?: string;
  search?: string;
};

type UseManagerialOptionsArgs = {
  costCenterId?: string;
  enabled: boolean;
  projectId?: string;
  search?: string;
  type: MANAGERIAL_TYPES;
};

type Paginated<T> = {
  data: T[];
  error: unknown;
  hasMore: boolean;
  isLoading: boolean;
  isLoadingMore: boolean;
  loadMore: () => void;
};

const buildKey = (
  baseUrl: string,
  baseParams: URLSearchParams,
  pageIndex: number,
  previousPageData: PaginatedCursorResponse<unknown> | null
): string | null => {
  if (previousPageData && previousPageData.next === null) return null;

  const params = new URLSearchParams(baseParams);
  if (pageIndex === 0) {
    params.set('page', '1');
  } else if (previousPageData?.next) {
    params.set('page', previousPageData.next);
  } else {
    return null;
  }

  return `${baseUrl}?${params.toString()}`;
};

const usePaginatedOptions = <T>(
  baseUrl: string,
  baseParams: URLSearchParams,
  enabled: boolean
): Paginated<T> => {
  const getKey: SWRInfiniteKeyLoader<PaginatedCursorResponse<T>> = (
    pageIndex,
    previousPageData
  ) => {
    if (!enabled) return null;
    return buildKey(baseUrl, baseParams, pageIndex, previousPageData);
  };

  const { data: pages, error, isValidating, setSize, size } = useSWRInfinite<
    PaginatedCursorResponse<T>
  >(getKey, fetcher, {
    revalidateFirstPage: false,
    keepPreviousData: false,
  });

  const data = useMemo(() => (pages ?? []).flatMap((page) => page.data), [pages]);

  const lastPage = pages?.[pages.length - 1];
  const hasMore = !!lastPage && lastPage.next !== null;

  const isLoadingInitial = enabled && !pages && !error;
  const isLoadingMore =
    isValidating && !!pages && pages.length > 0 && pages.length < size;

  const loadMore = useCallback(() => {
    if (!hasMore || isLoadingMore) return;
    setSize((current) => current + 1);
  }, [hasMore, isLoadingMore, setSize]);

  return {
    data,
    error,
    hasMore,
    isLoading: isLoadingInitial,
    isLoadingMore,
    loadMore,
  };
};

export function useProjectOptions({
  enabled,
  organizationId,
  search,
}: UseProjectOptionsArgs): Paginated<ProjectOption> {
  const baseParams = new URLSearchParams();
  if (organizationId) {
    baseParams.set('organizationId', organizationId);
  }
  if (search && search.trim().length > 0) {
    baseParams.set('search', search.trim());
  }
  return usePaginatedOptions<ProjectOption>('/api/configs/projects', baseParams, enabled);
}

export function useManagerialOptions({
  costCenterId,
  enabled,
  projectId,
  search,
  type,
}: UseManagerialOptionsArgs): Paginated<ManagerialOption> {
  const baseParams = new URLSearchParams({ type });
  if (type === MANAGERIAL_TYPES.COST_CENTER && projectId) {
    baseParams.set('projectId', projectId);
  }
  if (type === MANAGERIAL_TYPES.MANAGERIAL_ACCOUNT && costCenterId) {
    baseParams.set('costCenterId', costCenterId);
  }
  if (search && search.trim().length > 0) {
    baseParams.set('search', search.trim());
  }
  return usePaginatedOptions<ManagerialOption>(
    '/api/configs/managerials',
    baseParams,
    enabled
  );
}
