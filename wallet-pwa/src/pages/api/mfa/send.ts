import { prisma } from '@paggo/database';
import { createMfaSendRoute } from '@paggo/mfa/routes/auth/send';

export default createMfaSendRoute(prisma);
