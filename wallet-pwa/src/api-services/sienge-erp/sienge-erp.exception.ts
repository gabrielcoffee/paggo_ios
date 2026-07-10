import { HttpStatusCode } from 'axios';

import { BaseServiceException } from '@paggo/services/api';

export class ErpBillPaymentNotFoundError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillPaymentNotFoundError';

  constructor() {
    super(HttpStatusCode.NotFound, false, 'Pagamento não encontrado.');
  }
}

export class ErpBillNotSiengeCustomerError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillNotSiengeCustomerError';

  constructor() {
    super(
      HttpStatusCode.BadRequest,
      false,
      'Criação de título só está disponível para clientes Sienge.'
    );
  }
}

export class ErpBillPaymentNotConfirmedError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillPaymentNotConfirmedError';

  constructor() {
    super(
      HttpStatusCode.BadRequest,
      false,
      'O pagamento precisa estar confirmado para criar o título.'
    );
  }
}

export class ErpBillAlreadyExistsError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillAlreadyExistsError';

  constructor() {
    super(HttpStatusCode.Conflict, false, 'Este pagamento já possui um título no Sienge.');
  }
}

export class ErpBillMissingPackageError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillMissingPackageError';

  constructor() {
    super(HttpStatusCode.BadRequest, false, 'O pagamento não possui um pacote associado.');
  }
}

export class ErpBillAllocationIncompleteError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillAllocationIncompleteError';

  constructor() {
    super(
      HttpStatusCode.BadRequest,
      false,
      'Preencha a alocação do pagamento antes de criar o título.'
    );
  }
}

export class ErpBillInvalidIssuedDateError extends BaseServiceException {
  static readonly exceptionName = 'ErpBillInvalidIssuedDateError';

  constructor() {
    super(
      HttpStatusCode.BadRequest,
      false,
      'A data do documento não pode ser depois da data do pagamento.'
    );
  }
}

export class SiengeErpRequestError extends BaseServiceException {
  static readonly exceptionName = 'SiengeErpRequestError';

  constructor(statusCode: number, message: string) {
    super(statusCode, statusCode >= HttpStatusCode.InternalServerError, message);
  }
}
