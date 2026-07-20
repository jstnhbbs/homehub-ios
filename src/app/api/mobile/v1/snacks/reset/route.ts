import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { snackCompletions } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const { localDate } = z
      .object({ localDate: z.string().date() })
      .parse(await parseJsonBody(request));
    await db
      .delete(snackCompletions)
      .where(
        and(
          eq(snackCompletions.householdId, household.id),
          eq(snackCompletions.localDate, localDate),
        ),
      );
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
