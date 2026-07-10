import { HttpStatusCode } from 'axios';
import { NextApiResponse } from 'next';

import { route } from '@paggo/middlewares/paggo-route';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { getPackageById } from '@paggo/services/services';
import { HTTP_STATUS_CODES, HttpMethod, PaggoHttpError } from '@paggo/types';

async function get(req: NextApiRequestLogged, res: NextApiResponse) {
  try {
    const packageId = req.query.id as string;
    const response = await getPackageById(packageId);
    return res.status(HttpStatusCode.Ok).json(response);
  } catch (error: any) {
    if (error?.status && error?.message) {
      throw new PaggoHttpError({
        statusCode: error.status,
        message: error.message,
      });
    }

    throw new PaggoHttpError({
      statusCode: HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR,
      message:
        'Não foi possível buscar o pagamento duplicado. Por favor, tente novamente e, em caso de dúvidas entre em contato com o suporte usando o botão de ajuda na barra lateral.',
    });
  }
}

export default route({
  [HttpMethod.GET]: {
    handler: get,
  },
});
