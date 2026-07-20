import { z } from "zod";
import {
  calendarEventFormSchema,
  deleteMobileCalendarEvent,
  updateMobileCalendarEvent,
} from "@/lib/mobile/calendar-mutations";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const eventId = z.string().uuid().parse((await context.params).id);
    const input = calendarEventFormSchema.parse(await parseJsonBody(request));
    return mobileJson(await updateMobileCalendarEvent(household, eventId, input));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const eventId = z.string().uuid().parse((await context.params).id);
    return mobileJson(await deleteMobileCalendarEvent(household, eventId));
  } catch (error) {
    return handleMobileError(error);
  }
}
