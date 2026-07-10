import { MANAGERIAL_TYPES } from '@prisma/client';
import { HttpStatusCode } from 'axios';
import { z } from 'zod';

import { allocationsService } from '@paggo/configurations-service/allocations';
import { buildPaginationByQueryParams } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';
import { PaginatedCursorResponse } from '@paggo/types/api-routes';

import type { NextApiResponse } from 'next';

const querySchema = z.object({
  type: z.nativeEnum(MANAGERIAL_TYPES),
  projectId: z.string().uuid().optional(),
  costCenterId: z.string().uuid().optional(),
  search: z.string().optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

type ManagerialQuery = z.infer<typeof querySchema>;

type ManagerialOption = {
  id: string;
  name: string;
  code: string | null;
};

async function get(
  req: NextApiRequestLogged<ManagerialQuery>,
  res: NextApiResponse<PaginatedCursorResponse<ManagerialOption>>
) {
  const { costCenterId, projectId, search, type } = req.data;
  const pagination = buildPaginationByQueryParams(req.query, { perPage: 50 });
  const cursorType = type === MANAGERIAL_TYPES.COST_CENTER ? 'CostCenter' : 'ManagerialAccount';

  const result = await allocationsService.listAllocationOptions({
    context: req.user,
    type: cursorType,
    projectId,
    costCenterId,
    search,
    pagination,
  });

  return res.status(HttpStatusCode.Ok).json(result);
}

export default route({
  [HttpMethod.GET]: {
    handler: validateDto(querySchema, get),
  },
});
