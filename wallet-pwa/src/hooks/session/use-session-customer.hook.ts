import { axiosInstance } from '@paggo/core-utils';
import { defineServerAction } from '@paggo/services-client/common/common';

import { UpdateSessionCustomerSchemaDto } from '@/services/session/session.dto';

export const useSessionCustomer = () => {
  const updateSessioCustomer = defineServerAction(async (dto: UpdateSessionCustomerSchemaDto) => {
    return axiosInstance.patch('/api/session-customer', dto);
  });

  return { updateSessioCustomer };
};
