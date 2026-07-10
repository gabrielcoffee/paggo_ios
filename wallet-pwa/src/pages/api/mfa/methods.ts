import { prisma } from '@paggo/database';
import { createMfaMethodsRoute } from '@paggo/mfa/routes/auth/methods';

export default createMfaMethodsRoute(prisma);
