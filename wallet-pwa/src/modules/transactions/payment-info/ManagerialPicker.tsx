'use client';

import { useEffect, useRef, useState } from 'react';

import { MANAGERIAL_TYPES } from '@prisma/client';
import { Circle } from 'lucide-react';
import { useDebounce } from 'react-use';

import { Drawer, DrawerContent } from '@paggo/fend/components/atoms/drawer/drawer';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';
import { Input } from '@paggo/ui/legacy/components/atoms/input';

import { useManagerialOptions } from '@/modules/transactions/allocation/hooks';

type Props = {
  costCenterId?: string;
  onOpenChange: (open: boolean) => void;
  onSelect: (selection: { id: string; name: string }) => void;
  open: boolean;
  projectId?: string;
  title: string;
  type: MANAGERIAL_TYPES;
};

export function ManagerialPicker({
  costCenterId,
  onOpenChange,
  onSelect,
  open,
  projectId,
  title,
  type,
}: Props) {
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');

  useDebounce(
    () => {
      setDebouncedSearch(search);
    },
    250,
    [search]
  );

  const { data, error, hasMore, isLoading, isLoadingMore, loadMore } = useManagerialOptions({
    costCenterId,
    enabled: open,
    projectId,
    search: debouncedSearch,
    type,
  });

  useEffect(() => {
    if (!open) {
      setSearch('');
      setDebouncedSearch('');
    }
  }, [open]);

  const sentinelRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return;
    if (!open || !hasMore || isLoadingMore) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          loadMore();
        }
      },
      { rootMargin: '120px' }
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [open, hasMore, isLoadingMore, loadMore]);

  const showEmptyState = !isLoading && !error && data.length === 0;

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="bg-gray-900 text-white">
        <div className="flex items-center justify-center border-b border-gray-700 px-4 pb-3">
          <SemanticTypography.Title size="big" color="white-pure">
            {title}
          </SemanticTypography.Title>
        </div>

        <div className="border-b border-gray-700 px-4 py-3">
          <Input
            classNames={{
              base: '!p-0 !m-0',
              input: 'text-base',
              inputWrapper: 'bg-gray-800 border border-gray-700 rounded-md px-3 py-2 !h-auto',
            }}
            name="managerial-search"
            aria-label="managerial-search"
            placeholder="Buscar"
            value={search}
            onValueChange={setSearch}
          />
        </div>

        <div className="flex max-h-[60vh] min-h-[40vh] flex-col overflow-y-auto">
          {isLoading && (
            <div className="px-4 py-6 text-center">
              <SemanticTypography.Caption size="big" color="gray-400">
                Carregando...
              </SemanticTypography.Caption>
            </div>
          )}

          {!isLoading && !!error && (
            <div className="px-4 py-6 text-center">
              <SemanticTypography.Caption size="big" color="gray-400">
                Erro ao carregar. Tente novamente.
              </SemanticTypography.Caption>
            </div>
          )}

          {showEmptyState && (
            <div className="px-4 py-6 text-center">
              <SemanticTypography.Caption size="big" color="gray-400">
                Nenhum item disponível.
              </SemanticTypography.Caption>
            </div>
          )}

          {!isLoading &&
            !error &&
            data.map((item) => {
              const display = item.code ? `${item.code} ${item.name}` : item.name;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => {
                    onSelect({ id: item.id, name: item.name });
                    onOpenChange(false);
                  }}
                  className="flex w-full items-center justify-between border-b border-gray-800 px-4 py-4 text-left active:bg-gray-800"
                >
                  <SemanticTypography.Body size="big" color="white-pure">
                    {display}
                  </SemanticTypography.Body>
                  <Circle className="h-5 w-5 text-gray-500" />
                </button>
              );
            })}

          {!isLoading && !error && data.length > 0 && (
            <>
              <div ref={sentinelRef} aria-hidden="true" />
              {isLoadingMore && (
                <div className="px-4 py-4 text-center">
                  <SemanticTypography.Caption size="big" color="gray-400">
                    Carregando mais...
                  </SemanticTypography.Caption>
                </div>
              )}
            </>
          )}
        </div>
      </DrawerContent>
    </Drawer>
  );
}
