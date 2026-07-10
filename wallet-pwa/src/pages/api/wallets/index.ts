import { HttpStatusCode } from 'axios';

import { jsonBigInt } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { getUserWallets } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<any>) {
  const deleted = req.query.deleted ? req.query.deleted === 'true' : undefined;
  const wallets = await getUserWallets(req.user, { deleted });

  return res.status(HttpStatusCode.Ok).send(jsonBigInt(wallets));
}

export default route({
  [HttpMethod.GET]: { handler: get },
});
