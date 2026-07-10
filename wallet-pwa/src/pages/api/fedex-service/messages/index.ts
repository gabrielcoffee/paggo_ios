import axios, { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';
import { Message } from '@paggo/types/fedex';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<Message[]>) {
  if (!process.env.FEDEX_API_KEY || !process.env.NEXT_PUBLIC_FEDEX_PUBLIC_URL) {
    return res.status(HttpStatusCode.NoContent).end();
  }

  const queryParams = new URLSearchParams();

  queryParams.append('targetUser', req.user.email);
  queryParams.append('requiresAction', String(req.query.requiresAction));
  queryParams.append('solved', String(req.query.solved));
  queryParams.append('expired', String(req.query.expired));
  req.query.page && queryParams.append('page', String(req.query.page));
  req.query.limit && queryParams.append('limit', String(req.query.limit));

  const url = `${process.env.NEXT_PUBLIC_FEDEX_PUBLIC_URL}/v1/message?${queryParams}`;

  const response = await axios.get<Message[]>(url, {
    headers: {
      'API-KEY': process.env.FEDEX_API_KEY,
    },
  });

  return res
    .status(HttpStatusCode.Ok)
    .json(
      response.data.filter((message) =>
        message.event.data && message.event.data.customerId
          ? message.event.data.customerId === req.user.customerId
          : true
      )
    );
}

export default route({
  [HttpMethod.GET]: {
    handler: get,
  },
});
