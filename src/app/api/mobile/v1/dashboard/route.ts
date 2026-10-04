import {
  handleMobileError,
  requireMobileContext,
  mobileJson,
} from "@/lib/mobile/http";
import { buildDashboardPayload } from "@/lib/mobile/dashboard";

export async function GET() {
  try {
    const { user, household } = await requireMobileContext();
    return mobileJson(await buildDashboardPayload(household, user.id));
  } catch (error) {
    return handleMobileError(error);
  }
}
