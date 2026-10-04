import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  serializeHousehold,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        snackOptions: z.string().max(2000).optional(),
        snacksPerChild: z.boolean().optional(),
      })
      .refine(
        (value) =>
          value.snackOptions !== undefined || value.snacksPerChild !== undefined,
        { message: "Nothing to update." },
      )
      .parse(await parseJsonBody(request));

    await db
      .update(households)
      .set({
        ...(input.snackOptions !== undefined && {
          snackOptions: input.snackOptions,
        }),
        ...(input.snacksPerChild !== undefined && {
          snacksPerChild: input.snacksPerChild,
        }),
        updatedAt: new Date(),
      })
      .where(eq(households.id, household.id));

    return mobileJson(serializeHousehold(await requireMobileHousehold()));
  } catch (error) {
    return handleMobileError(error);
  }
}
