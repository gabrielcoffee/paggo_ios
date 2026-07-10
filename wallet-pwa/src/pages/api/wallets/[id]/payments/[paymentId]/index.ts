import { HttpStatusCode } from 'axios';

import { jsonBigInt } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { getWalletPayment } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<any>) {
  const transaction = await getWalletPayment(req.id, req.query.paymentId as string, req.user);

  return res.status(HttpStatusCode.Ok).send(jsonBigInt(transaction));
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
