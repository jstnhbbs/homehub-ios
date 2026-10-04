import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles, snackCompletions } from "@/db/schema";
import { SHARED_SNACK_PROFILE, parseSnackOptions } from "@/lib/meals/snacks";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

export async function POST(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const input = z
      .object({
        localDate: z.string().date(),
        snackLabel: shortText,
        // Which child ate it. Only used when the household tracks snacks per child; older app
        // versions never send it and keep checking snacks off for everyone.
        profileId: z.string().uuid().optional(),
      })
      .parse(await parseJsonBody(request));

    const allowed = parseSnackOptions(household.snackOptions);
    if (!allowed.includes(input.snackLabel)) {
      throw new Error("Snack not found.");
    }

    // Per-child tracking needs at least one child; without any, the household-wide checklist
    // keeps working rather than every tap failing.
    const children = household.snacksPerChild
      ? await db
          .select({ id: profiles.id })
          .from(profiles)
          .where(
            and(
              eq(profiles.householdId, household.id),
              eq(profiles.profileType, "child"),
            ),
          )
      : [];

    let profileId = SHARED_SNACK_PROFILE;
    if (children.length > 0) {
      if (!input.profileId) {
        throw new Error("Choose which child ate this snack.");
      }
      const child = children.find((item) => item.id === input.profileId);
      if (!child) throw new Error("Invalid child profile.");
      profileId = child.id;
    }

    const match = and(
      eq(snackCompletions.householdId, household.id),
      eq(snackCompletions.localDate, input.localDate),
      eq(snackCompletions.snackLabel, input.snackLabel),
      eq(snackCompletions.profileId, profileId),
    );

    const existing = await db
      .select({ snackLabel: snackCompletions.snackLabel })
      .from(snackCompletions)
      .where(match)
      .limit(1);

    if (existing[0]) {
      await db.delete(snackCompletions).where(match);
    } else {
      await db
        .insert(snackCompletions)
        .values({
          householdId: household.id,
          localDate: input.localDate,
          snackLabel: input.snackLabel,
          profileId,
        })
        .onConflictDoNothing();
    }

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
