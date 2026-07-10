import { prisma } from '@paggo/database';
import { createMfaVerifyRoute } from '@paggo/mfa/routes/auth/verify';

export default createMfaVerifyRoute(prisma);
