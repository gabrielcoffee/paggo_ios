import { Prisma } from '@prisma/client';

type AllocationLine = {
  projectId?: string | null;
  costCenterId?: string | null;
  managerialAccountId?: string | null;
  project?: { id?: string | null } | null;
  costCenter?: { id?: string | null } | null;
  managerialAccount?: { id?: string | null } | null;
  allocation?: number | Prisma.Decimal | null;
};

export const ALLOCATION_FEATURE_RELEASE_DATE = '2026-04-27T00:00:00Z';

export function isAllocationComplete(allocations: AllocationLine[] | null | undefined): boolean {
  if (!allocations || allocations.length === 0) return false;

  const everyFieldFilled = allocations.every(
    (a) =>
      !!(a.projectId ?? a.project?.id) &&
      !!(a.costCenterId ?? a.costCenter?.id) &&
      !!(a.managerialAccountId ?? a.managerialAccount?.id)
  );
  if (!everyFieldFilled) return false;

  const sum = allocations.reduce((acc, a) => acc + Number(a.allocation ?? 0), 0);

  return Math.abs(sum - 100) < 0.01;
}

export function isAllocationEmpty(allocations: AllocationLine[] | null | undefined): boolean {
  return !allocations || allocations.length === 0;
}

export function shouldFlagAllocationPending(
  pkg: { allocations?: AllocationLine[] | null } | null | undefined,
  paymentCreatedAt: Date | string | null | undefined
): boolean {
  if (!paymentCreatedAt) return false;
  return !isAllocationComplete(pkg?.allocations);
}
