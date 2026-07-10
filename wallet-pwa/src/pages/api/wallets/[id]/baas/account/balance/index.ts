import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { getUserWalletAccountBalance } from '@paggo/services/services';
import { HttpMethod, HTTP_STATUS_CODES, PaggoHttpError } from '@paggo/types';
import { generateBffTokenFromWallet } from '@paggo/utils/baas';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<any>) {
  const token = await generateBffTokenFromWallet(
    req.query.id,
    req.user.email,
    req.user.currentUserCustomer.customerId
  );

  if (!token) {
    throw new PaggoHttpError({
      statusCode: HTTP_STATUS_CODES.UNAUTHORIZED,
      message: 'Erro na Autenticação com o Banco',
    });
  }

  const balanceResponse = await getUserWalletAccountBalance(req.id, req.user, token);

  return res.status(HttpStatusCode.Ok).send(balanceResponse);
}

export default route(
  {
    [HttpMethod.GET]: {
      handler: get,
    },
  },
  { validateDynamic: true }
);
