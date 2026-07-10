import { RESOURCES } from '@prisma/client';
import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';

import {
  CreateErpBillStatusQueryDto,
  createErpBillStatusQueryDtoSchema,
  CreateErpBillStatusResponse,
} from '@/api-services/sienge-erp/sienge-erp.dto';
import { getCreateErpBillStatus } from '@/api-services/sienge-erp/sienge-erp.service';

import type { NextApiResponse } from 'next';

async function get(
  req: NextApiRequestLogged<CreateErpBillStatusQueryDto>,
  res: NextApiResponse<CreateErpBillStatusResponse>
) {
  const status = await getCreateErpBillStatus({
    customerId: req.user.currentUserCustomer.customerId,
    documentNumber: req.data.documentNumber,
  });

  return res.status(HttpStatusCode.Ok).json(status);
}

export default route(
  {
    [HttpMethod.GET]: {
      handler: validateDto(createErpBillStatusQueryDtoSchema, get),
      necessaryResources: [RESOURCES.VIEW_PAYMENTS],
    },
  },
  { validateDynamic: true }
);
