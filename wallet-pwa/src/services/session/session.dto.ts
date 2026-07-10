import { z } from 'zod';

export const updateSessionCustomerSchemaDto = z.object({
  customerId: z.string(),
});

export type UpdateSessionCustomerSchemaDto = z.infer<typeof updateSessionCustomerSchemaDto>;
