import { HttpStatusCode } from 'axios';

import { jsonBigInt } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  CreateWalletPaymentIntentDto,
  createWalletPaymentIntentDtoSchema,
} from '@paggo/services/dto';
import { createWalletPaymentIntent } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function create(
  req: NextApiRequestLogged<CreateWalletPaymentIntentDto>,
  res: NextApiResponse<any>
) {
  const entity = await createWalletPaymentIntent(req.id, req.user, req.data);

  return res.status(HttpStatusCode.Ok).send(jsonBigInt(entity));
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(createWalletPaymentIntentDtoSchema, create),
    },
  },
  {
    validateDynamic: true,
  }
);
