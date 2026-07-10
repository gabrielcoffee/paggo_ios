import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { ValidateWalletUserPinDto, validateWalletUserPinDtoSchema } from '@paggo/services/dto';
import { validateWalletUserPin } from '@paggo/services/services';
import { HTTP_STATUS_CODES, HttpMethod, PaggoHttpError } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function validate(
  req: NextApiRequestLogged<ValidateWalletUserPinDto>,
  res: NextApiResponse<any>
) {
  const valid = await validateWalletUserPin(req.id, req.user, req.data);

  if (valid) {
    return res.status(HttpStatusCode.Ok).json({ valid });
  }

  throw new PaggoHttpError({
    statusCode: HTTP_STATUS_CODES.FORBIDDEN,
    message: 'Falha ao verificar o PIN',
  });
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(validateWalletUserPinDtoSchema, validate),
    },
  },
  {
    validateDynamic: true,
  }
);
