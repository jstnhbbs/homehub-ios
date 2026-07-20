import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";
import { buildDashboardPayload } from "@/lib/mobile/dashboard";

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    return mobileJson(await buildDashboardPayload(household));
  } catch (error) {
    return handleMobileError(error);
  }
}
