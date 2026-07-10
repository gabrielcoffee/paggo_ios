import axios, { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';

import type { NextApiResponse } from 'next';

async function get(req: NextApiRequestLogged, res: NextApiResponse<string>) {
  if (!process.env.FEDEX_API_KEY) return res.status(HttpStatusCode.NoContent).end();

  const url = `${process.env.NEXT_PUBLIC_FEDEX_PUBLIC_URL}/v1/auth`;

  const response = await axios.post<string>(
    url,
    {
      email: req.user.email,
      deviceUsed: req.headers['user-agent']?.toString(),
    },
    {
      headers: {
        'API-KEY': process.env.FEDEX_API_KEY,
      },
    }
  );

  return res.status(HttpStatusCode.Ok).json(response?.data);
}

export default route({ GET: { handler: get } });
