type WalletPaymentDetailsWithPackage = {
  packageId?: string | null;
  deliveryDocument?: {
    deliveryDocumentPackages?: {
      packageId?: string | null;
      package?: {
        packageErp?: {
          billId?: string | null;
        } | null;
      } | null;
    }[];
  } | null;
};

export function extractPackageId(
  data: WalletPaymentDetailsWithPackage | null | undefined
): string | undefined {
  if (!data) return undefined;
  const firstPackage = data.deliveryDocument?.deliveryDocumentPackages?.[0];
  return data.packageId ?? firstPackage?.packageId ?? undefined;
}

export function hasErpBill(data: WalletPaymentDetailsWithPackage | null | undefined): boolean {
  if (!data) return false;
  const firstPackage = data.deliveryDocument?.deliveryDocumentPackages?.[0];
  return !!firstPackage?.package?.packageErp?.billId;
}
