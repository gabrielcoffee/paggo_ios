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
  organizationId: z.string().uuid().optional(),
  search: z.string().optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

type ProjectsQuery = z.infer<typeof querySchema>;

type ProjectOption = {
  id: string;
  name: string;
};

async function get(
  req: NextApiRequestLogged<ProjectsQuery>,
  res: NextApiResponse<PaginatedCursorResponse<ProjectOption>>
) {
  const pagination = buildPaginationByQueryParams(req.query, { perPage: 50 });

  const result = await allocationsService.listActiveProjects({
    context: req.user,
    organizationId: req.data.organizationId,
    pagination,
    search: req.data.search,
  });

  return res.status(HttpStatusCode.Ok).json(result);
}

export default route({
  [HttpMethod.GET]: {
    handler: validateDto(querySchema, get),
  },
});
