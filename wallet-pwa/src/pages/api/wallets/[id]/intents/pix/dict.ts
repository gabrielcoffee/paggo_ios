import { HttpStatusCode } from 'axios';
import { trimEnd } from 'lodash';

import { getBankName } from '@paggo/constants';
import { cnpjValid, cpfValid, isPixQRCode, mapToNumeric } from '@paggo/core-utils';
import { route } from '@paggo/middlewares/paggo-route';
import { validateDto } from '@paggo/middlewares/single-validation/dto-validator';
import { NextApiRequestLogged } from '@paggo/middlewares/types';
import {
  SearchPixDictWalletPaymentDto,
  searchPixDictWalletPaymentDtoSchema,
} from '@paggo/services/dto';
import { searchPixDictKey } from '@paggo/services/services';
import {
  WalletPaymentBankAuthFailedError,
  WalletPaymentInvalidPixKeyError,
  WalletPaymentPixKeyNotFoundError,
} from '@paggo/services/services/wallet/wallet.exception';
import { HttpMethod, HTTP_STATUS_CODES } from '@paggo/types';
import { generateBffTokenFromWallet, PixDictResult } from '@paggo/utils/baas';

import { BaasMockedResponses } from '@/utils';

import type { NextApiResponse } from 'next';

async function search(
  req: NextApiRequestLogged<SearchPixDictWalletPaymentDto>,
  res: NextApiResponse<PixDictResult>
) {
  if (process.env.NODE_ENV === 'development' && process.env.FORCE_BAAS !== '1') {
    const responseData: PixDictResult = {
      id: BaasMockedResponses.dict.id,
      key: BaasMockedResponses.dict.key,
      accountNumber: BaasMockedResponses.dict.accountNumber,
      accountType: BaasMockedResponses.dict.accountType as any,
      branchCode: BaasMockedResponses.dict.branchCode,
      taxId: BaasMockedResponses.dict.receiverTaxId,
      type: BaasMockedResponses.dict.type as any,
      ispb: BaasMockedResponses.dict.bankCode,
      name: trimEnd(BaasMockedResponses.dict.receiverLegalName),
      bankName: getBankName(BaasMockedResponses.dict.bankCode),
      endToEndId: BaasMockedResponses.dict.endToEndId,
      status: 'registered',
      created: null,
      owned: null,
      ownerType: null,
    };

    return res.status(HttpStatusCode.Ok).json(responseData);
  }

  const token = await generateBffTokenFromWallet(
    req.query.id,
    req.user.email,
    req.user.currentUserCustomer.customerId
  );

  if (!token) {
    throw new WalletPaymentBankAuthFailedError();
  }

  const originalDictKey = req.data.pixKey;

  const isQRCode = isPixQRCode(originalDictKey);

  if (isQRCode) {
    throw new WalletPaymentInvalidPixKeyError();
  }

  const numericDictKey = mapToNumeric(originalDictKey ?? '');
  let pixKey = originalDictKey;

  if (numericDictKey.length === 14 && cnpjValid(numericDictKey)) {
    pixKey = numericDictKey;
  } else if (numericDictKey.length === 13 && numericDictKey.startsWith('55')) {
    pixKey = '+' + numericDictKey;
  } else if (numericDictKey.length === 12 && numericDictKey.startsWith('0')) {
    pixKey = '+55' + numericDictKey.slice(1);
  } else if (numericDictKey.length === 11) {
    pixKey = cpfValid(numericDictKey) ? numericDictKey : '+55' + numericDictKey;
  } else if (numericDictKey.length === 10) {
    pixKey = '+55' + numericDictKey;
  }

  const key = pixKey ?? originalDictKey;

  try {
    const entity = await searchPixDictKey(req.id, req.user, key, token);
    return res.status(HttpStatusCode.Ok).json(entity);
  } catch (error: any) {
    if (error?.status === HTTP_STATUS_CODES.NOT_FOUND) {
      throw new WalletPaymentPixKeyNotFoundError();
    }

    throw error;
  }
}

export default route(
  {
    [HttpMethod.POST]: {
      handler: validateDto(searchPixDictWalletPaymentDtoSchema, search),
    },
  },
  {
    validateDynamic: true,
  }
);
