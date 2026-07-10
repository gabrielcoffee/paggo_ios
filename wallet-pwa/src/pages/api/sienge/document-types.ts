import { RESOURCES } from '@prisma/client';
import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';

import { getSiengeDocumentTypes } from '@/api-services/sienge-erp/sienge-erp.service';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse) {
  const documentTypes = await getSiengeDocumentTypes(req.user.currentUserCustomer.customerId);
  return res.status(HttpStatusCode.Ok).json(documentTypes);
}

export default route({
  [HttpMethod.GET]: {
    handler: get,
    necessaryResources: [RESOURCES.EDIT_PAYMENTS],
  },
});
