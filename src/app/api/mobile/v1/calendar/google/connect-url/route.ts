import { googleAuthUrl, googleOAuthState } from "@/lib/google/oauth";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileParentHousehold();
    const allowed = await checkRateLimit("calendar-connect", household.id, {
      limit: 5,
      windowMs: 15 * 60 * 1000,
    });
    if (!allowed) {
      throw new Error("Too many connection attempts. Try again later.");
    }

    const state = googleOAuthState(household.id, { mobile: true });
    return mobileJson({ url: googleAuthUrl(state) });
  } catch (error) {
    return handleMobileError(error);
  }
}
