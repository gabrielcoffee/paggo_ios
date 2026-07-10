import { HttpStatusCode } from 'axios';
import { z } from 'zod';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { Payout } from '@paggo/payments-service/payout/payout.service';
import { updateWalletPaymentAllocationsRequestDtoSchema } from '@paggo/payments-service/wallet-payment-allocation/wallet-payment-allocation.schema';
import {
  GetWalletPaymentAllocationsResponseDto,
  UpdateWalletPaymentAllocationsResponseDto,
} from '@paggo/payments-service/wallet-payment-allocation/wallet-payment-allocation.type';
import { HttpMethod } from '@paggo/types';

import type { NextApiResponse } from 'next';

const paymentIdSchema = z.string().uuid();

const updateBodyDtoSchema = updateWalletPaymentAllocationsRequestDtoSchema.pick({
  allocations: true,
  packageId: true,
});

type UpdateBodyDto = z.infer<typeof updateBodyDtoSchema>;

async function get(
  req: NextApiRequestLogged,
  res: NextApiResponse<GetWalletPaymentAllocationsResponseDto>
) {
  const paymentId = paymentIdSchema.parse(req.query.paymentId);
  const result = await Payout.getWalletPaymentAllocations({
    walletId: req.id,
    paymentId,
    customerId: req.user.customerId,
    userId: req.user.userId,
  });

  return res.status(HttpStatusCode.Ok).json(result);
}

async function patch(
  req: NextApiRequestLogged<UpdateBodyDto>,
  res: NextApiResponse<UpdateWalletPaymentAllocationsResponseDto>
) {
  const paymentId = paymentIdSchema.parse(req.query.paymentId);
  const result = await Payout.updateWalletPaymentAllocations({
    walletId: req.id,
    paymentId,
    customerId: req.user.customerId,
    userId: req.user.userId,
    packageId: req.data.packageId,
    allocations: req.data.allocations,
  });

  const statusCode = result.status === 'updated' ? HttpStatusCode.Ok : HttpStatusCode.Accepted;
  return res.status(statusCode).json(result);
}

export default route(
  {
    [HttpMethod.GET]: {
      handler: get,
    },
    [HttpMethod.PATCH]: {
      handler: validateDto(updateBodyDtoSchema, patch),
    },
  },
  {
    validateDynamic: true,
  }
);
