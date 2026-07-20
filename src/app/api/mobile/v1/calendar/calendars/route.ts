import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";
import { listEnabledCalendars } from "@/lib/mobile/calendar-events";

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    return mobileJson(await listEnabledCalendars(household.id));
  } catch (error) {
    return handleMobileError(error);
  }
}
