import { z } from "zod";
import { disconnectICloud } from "@/lib/caldav/client";
import { disconnectGoogleCalendar } from "@/lib/google/calendar";
import {
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ provider: string }> };

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const provider = z.enum(["icloud", "google"]).parse((await context.params).provider);

    if (provider === "google") {
      await disconnectGoogleCalendar(household.id);
    } else {
      await disconnectICloud(household.id);
    }

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
