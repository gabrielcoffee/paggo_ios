import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  CreateWalletPaymentAttachmentsDto,
  createWalletPaymentAttachmentsDtoSchema,
} from '@paggo/services/dto';
import { addWalletPaymentAttachments } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function create(
  req: NextApiRequestLogged<CreateWalletPaymentAttachmentsDto>,
  res: NextApiResponse<any>
) {
  const response = await addWalletPaymentAttachments(
    req.query.paymentId as string,
    req.id,
    req.user,
    req.data
  );
  return res.status(HttpStatusCode.Ok).json(response);
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(createWalletPaymentAttachmentsDtoSchema, create),
    },
  },
  {
    validateDynamic: true,
  }
);
