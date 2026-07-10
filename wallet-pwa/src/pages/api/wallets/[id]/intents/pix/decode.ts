import { HttpStatusCode } from 'axios';

import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  DecodeQRCodeWalletPaymentDto,
  decodeQRCodeWalletPaymentDtoSchema,
} from '@paggo/services/dto';
import { decodeQRCode } from '@paggo/services/services';
import { HttpMethod, HTTP_STATUS_CODES, PaggoHttpError } from '@paggo/types';
import { DecodeQRCodePaymentResult, generateBffTokenFromWallet } from '@paggo/utils/baas';

import { BaasMockedResponses } from '@/utils/';

import type { NextApiResponse } from 'next';

async function decode(
  req: NextApiRequestLogged<DecodeQRCodeWalletPaymentDto>,
  res: NextApiResponse<DecodeQRCodePaymentResult>
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
    const responseData: DecodeQRCodePaymentResult = {
      key: BaasMockedResponses.emv.decode.key,
      qrCode: BaasMockedResponses.emv.decode.qrCode,
    };

    return res.status(HttpStatusCode.Ok).json(responseData);
  }

  try {
    const entity = await decodeQRCode(req.id, req.user, req.data.emv, token);

    return res.status(HttpStatusCode.Ok).json(entity);
  } catch (error: unknown) {
    const status = (error as { status?: number })?.status;
    if (status && status >= 400 && status < 500) {
      throw new PaggoHttpError({
        statusCode: HTTP_STATUS_CODES.BAD_REQUEST,
        message: 'QRCode inválido. Verifique o código e tente novamente.',
        captureException: false,
      });
    }
    throw error;
  }
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(decodeQRCodeWalletPaymentDtoSchema, decode),
    },
  },
  {
    validateDynamic: true,
  }
);
