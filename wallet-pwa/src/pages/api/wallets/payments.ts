import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { WalletPaymentsApiResponse } from '@paggo/services/prisma/payment.prisma';
import { getWalletPayments } from '@paggo/services/services';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<WalletPaymentsApiResponse>) {
  const wallets = await getWalletPayments(req.user);

  const response = {
    items: wallets,
  };

  return res.status(HttpStatusCode.Ok).send(response);
}

export default route({
  [HttpMethod.GET]: { handler: get },
});
