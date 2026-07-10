import { get } from '@vercel/edge-config';
import { HttpStatusCode } from 'axios';
import { NextApiResponse } from 'next';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';

async function verify(req: NextApiRequestLogged, res: NextApiResponse) {
  let expectedMaintenanceEnd;
  if (process.env.EDGE_CONFIG) {
    try {
      // Check whether the maintenance page should be shown
      expectedMaintenanceEnd = await get<string>('expectedMaintenanceEnd');
    } catch (error) {
      console.error(error);
    }
  }

  res.status(HttpStatusCode.Ok).json({ expectedMaintenanceEnd });
}

export default route({
  GET: { handler: verify },
});
