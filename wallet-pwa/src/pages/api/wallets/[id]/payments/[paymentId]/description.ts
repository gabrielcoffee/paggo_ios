import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  AddWalletPaymentDescriptionDtoSchema,
  addWalletPaymentDescriptionDtoSchema,
} from '@paggo/services/dto';
import { addWalletDescription } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function patch(
  req: NextApiRequestLogged<AddWalletPaymentDescriptionDtoSchema>,
  res: NextApiResponse<any>
) {
  const response = await addWalletDescription(
    req.query.paymentId as string,
    req.id,
    req.user,
    req.data
  );
  return res.status(HttpStatusCode.Ok).json(response);
}

export default route(
  {
    [HttpMethod.PATCH]: {
      handler: validateDto(addWalletPaymentDescriptionDtoSchema, patch),
    },
  },
  {
    validateDynamic: true,
  }
);
