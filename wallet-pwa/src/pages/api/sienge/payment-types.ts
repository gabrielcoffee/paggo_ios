import { RESOURCES } from '@prisma/client';
import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';

import {
  GetSiengePaymentTypesQueryDto,
  getSiengePaymentTypesQueryDtoSchema,
  SiengePaymentTypeOption,
} from '@/api-services/sienge-erp/sienge-erp.dto';
import { getSiengePaymentTypeOptions } from '@/api-services/sienge-erp/sienge-erp.service';

import type { NextApiResponse } from 'next';

async function get(
  req: NextApiRequestLogged<GetSiengePaymentTypesQueryDto>,
  res: NextApiResponse<SiengePaymentTypeOption[]>
) {
  const paymentTypes = await getSiengePaymentTypeOptions(
    req.user.currentUserCustomer.customerId,
    req.data.paymentMethod
  );
  return res.status(HttpStatusCode.Ok).json(paymentTypes);
}

export default route({
  [HttpMethod.GET]: {
    handler: validateDto(getSiengePaymentTypesQueryDtoSchema, get),
    necessaryResources: [RESOURCES.EDIT_PAYMENTS],
  },
});
