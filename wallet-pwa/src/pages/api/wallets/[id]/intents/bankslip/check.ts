import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  CheckBankslipWalletPaymentDto,
  checkBankslipWalletPaymentDtoSchema,
} from '@paggo/services/dto';
import { checkBankslip } from '@paggo/services/services';
import { HttpMethod, HTTP_STATUS_CODES, PaggoHttpError } from '@paggo/types';
import type { BaasBankslipCheck, TNextSettle } from '@paggo/types/baas';
import { generateBffTokenFromWallet } from '@paggo/utils/baas';

import { BaasMockedResponses } from '@/utils/';

import type { NextApiResponse } from 'next';

async function check(
  req: NextApiRequestLogged<CheckBankslipWalletPaymentDto>,
  res: NextApiResponse<BaasBankslipCheck>
) {
  const token = await generateBffTokenFromWallet(
    req.query.id,
    req.user.email,
    req.user.currentUserCustomer.customerId
  );

  if (!token) {
    throw new PaggoHttpError({
      statusCode: HTTP_STATUS_CODES.UNAUTHORIZED,
      message: 'Erro na Autenticação com o Banco',
    });
  }

  if (process.env.NODE_ENV === 'development' && process.env.FORCE_BAAS !== '1') {
    const responseData: BaasBankslipCheck = {
      ...BaasMockedResponses.bankslip.check,
      nextSettle: BaasMockedResponses.bankslip.check.nextSettle as TNextSettle,
      bankslipType: BaasMockedResponses.bankslip.check.type,
      paymentDetails: null,
      registerData: {
        ...BaasMockedResponses.bankslip.check.registerData,
        nextBusinessDay: null,
      },
    };

    return res.status(HttpStatusCode.Ok).json(responseData);
  }

  try {
    const entity = await checkBankslip(req.id, req.user, req.data.digitable, token);
    return res.status(HttpStatusCode.Ok).json(entity);
  } catch (error: any) {
    if (error?.status && error?.message) {
      throw new PaggoHttpError({
        statusCode: error.status,
        message: error.message,
      });
    }

    throw new PaggoHttpError({
      statusCode: HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR,
      message: 'Não foi possível obter as informações do código de barras neste momento',
    });
  }
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(checkBankslipWalletPaymentDtoSchema, check),
    },
  },
  {
    validateDynamic: true,
  }
);
