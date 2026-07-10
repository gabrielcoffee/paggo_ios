import { NextApiRequest, NextApiResponse } from 'next';

import { authOptions } from '@paggo/auth/config';
import { prisma } from '@paggo/database';

import NextAuth from '@paggotech/next-auth';

const nextAuthInstance = (req: NextApiRequest, res: NextApiResponse) =>
  NextAuth(req, res, authOptions(prisma, req, res));

export default nextAuthInstance;
