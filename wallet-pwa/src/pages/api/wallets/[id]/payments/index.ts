import { HttpStatusCode } from 'axios';

import { jsonBigInt } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { getWalletPaymentsByWallet } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<any>) {
  const transactions = await getWalletPaymentsByWallet(req.id, req.user);

  const response = {
    items: transactions,
  };

  return res.status(HttpStatusCode.Ok).send(jsonBigInt(response));
}

export default route(
  {
    [HttpMethod.GET]: {
      handler: get,
    },
  },
  {
    validateDynamic: true,
  }
);
