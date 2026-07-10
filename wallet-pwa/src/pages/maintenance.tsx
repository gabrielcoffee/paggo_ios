import { usePlatformMaintenance } from '@paggo/services-client/hooks/use-platform-maintenance';
import Maintenance from '@paggo/ui/components/pages/maintenance/Maintenance';

export default function MaintenanceHome() {
  const { data } = usePlatformMaintenance();
  return <Maintenance expectedMaintenanceEnd={data?.expectedMaintenanceEnd} />;
}
