import { RESOURCES } from '@prisma/client';
import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { HttpMethod } from '@paggo/types';

import {
  CreateErpBillRequestDto,
  createErpBillRequestDtoSchema,
  CreateErpBillResponseDto,
  GetErpBillQueryDto,
  getErpBillQueryDtoSchema,
  GetErpBillResponse,
} from '@/api-services/sienge-erp/sienge-erp.dto';
import {
  createErpBillForWalletPayment,
  getWalletPaymentErpBill,
} from '@/api-services/sienge-erp/sienge-erp.service';

import type { NextApiResponse } from 'next';

async function get(
  req: NextApiRequestLogged<GetErpBillQueryDto>,
  res: NextApiResponse<GetErpBillResponse>
) {
  const bill = await getWalletPaymentErpBill({
    paymentId: req.data.paymentId,
    walletId: req.id,
    customerId: req.user.currentUserCustomer.customerId,
  });

  return res.status(HttpStatusCode.Ok).json({ bill });
}

async function post(
  req: NextApiRequestLogged<CreateErpBillRequestDto>,
  res: NextApiResponse<CreateErpBillResponseDto>
) {
  await createErpBillForWalletPayment({
    paymentId: req.query.paymentId?.toString() ?? '',
    walletId: req.id,
    customerId: req.user.currentUserCustomer.customerId,
    data: req.data,
  });

  return res.status(HttpStatusCode.Accepted).json({ success: true });
}

export default route(
  {
    [HttpMethod.GET]: {
      handler: validateDto(getErpBillQueryDtoSchema, get),
      necessaryResources: [RESOURCES.VIEW_PAYMENTS],
    },
    [HttpMethod.POST]: {
      handler: validateDto(createErpBillRequestDtoSchema, post),
      necessaryResources: [RESOURCES.EDIT_PAYMENTS],
    },
  },
  { validateDynamic: true }
);
