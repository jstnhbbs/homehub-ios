import { and, eq } from "drizzle-orm";
import { addDays, format, parseISO } from "date-fns";
import { z } from "zod";
import { db } from "@/db/client";
import { meals } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const { weekStart } = z
      .object({ weekStart: z.string().date() })
      .parse(await parseJsonBody(request));
    const start = parseISO(weekStart);
    const dates = Array.from({ length: 7 }, (_, index) =>
      format(addDays(start, index), "yyyy-MM-dd"),
    );
    for (const localDate of dates) {
      await db
        .delete(meals)
        .where(
          and(
            eq(meals.householdId, household.id),
            eq(meals.localDate, localDate),
          ),
        );
    }
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
