import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { applyCompletion } from "@/lib/completion-state";
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
        // The state the app wants. Left out by older apps, which means "flip it".
        completed: z.boolean().optional(),
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

    const completed = await applyCompletion(input.completed, {
      isDone: async () =>
        Boolean(
          (
            await db
              .select({ snackLabel: snackCompletions.snackLabel })
              .from(snackCompletions)
              .where(match)
              .limit(1)
          )[0],
        ),
      mark: async () => {
        await db
          .insert(snackCompletions)
          .values({
            householdId: household.id,
            localDate: input.localDate,
            snackLabel: input.snackLabel,
            profileId,
          })
          .onConflictDoNothing();
      },
      unmark: async () => {
        await db.delete(snackCompletions).where(match);
      },
    });

    return mobileJson({ ok: true, completed });
  } catch (error) {
    return handleMobileError(error);
  }
}
