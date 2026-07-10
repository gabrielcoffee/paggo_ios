import { HttpStatusCode } from 'axios';

import { prisma } from '@paggo/database';
import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';

import {
  UpdateSessionCustomerSchemaDto,
  updateSessionCustomerSchemaDto,
} from '@/services/session/session.dto';

import type { NextApiResponse } from 'next';

async function patch(
  req: NextApiRequestLogged<UpdateSessionCustomerSchemaDto>,
  res: NextApiResponse<any>
) {
  const userId = req.user.userId;
  if (!userId) {
    return res.status(HttpStatusCode.Forbidden).json({ failed: true });
  }
  const availableCustomers = await prisma.userCustomer.findMany({
    where: {
      userId,
    },
  });

  if (!availableCustomers.find((f) => f.customerId === req.data.customerId)) {
    return res.status(HttpStatusCode.Forbidden).json({ failed: true });
  }

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      sessionCustomer: req.data.customerId,
    },
  });
  return res.status(HttpStatusCode.Ok).json(user);
}

export default route({
  [HttpMethod.PATCH]: {
    handler: validateDto(updateSessionCustomerSchemaDto, patch),
  },
});
