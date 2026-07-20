import { z } from "zod";
import {
  calendarEventFormSchema,
  createMobileCalendarEvent,
} from "@/lib/mobile/calendar-mutations";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";
import { buildCalendarOccurrences } from "@/lib/mobile/calendar-events";

export async function GET(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const params = new URL(request.url).searchParams;
    const start = z.string().date().parse(params.get("start"));
    const end = z.string().date().parse(params.get("end"));
    const query = params.get("q") ?? "";
    return mobileJson(
      await buildCalendarOccurrences(household, start, end, query),
    );
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = calendarEventFormSchema.parse(await parseJsonBody(request));
    return mobileJson(await createMobileCalendarEvent(household, input), 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
