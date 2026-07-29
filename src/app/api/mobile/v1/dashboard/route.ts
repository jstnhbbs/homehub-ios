import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";
import { buildDashboardPayload } from "@/lib/mobile/dashboard";

export async function GET() {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    return mobileJson(await buildDashboardPayload(household, user.id));
  } catch (error) {
    return handleMobileError(error);
  }
}
