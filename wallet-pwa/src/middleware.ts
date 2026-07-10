import { get } from '@vercel/edge-config';
import { NextResponse } from 'next/server';

import type { NextRequest } from 'next/server';

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - images
     * - assets
     * - service worker files
     */
    '/((?!api|_next/static|_next/image|favicon.ico|images|assets|workbox-|fallback-|sw.js).*)',
  ],
};

export async function middleware(req: NextRequest) {
  if (process.env.EDGE_CONFIG) {
    try {
      // Check whether the maintenance page should be shown
      const isInMaintenanceMode = await get<boolean>('isInMaintenanceModeWallet');

      // If is in maintenance mode, point the url pathname to the maintenance page
      if (isInMaintenanceMode) {
        req.nextUrl.pathname = '/maintenance';

        // Rewrite to the url
        return NextResponse.rewrite(req.nextUrl);
      }
    } catch (error) {
      console.error(error);
    }
  }
}
