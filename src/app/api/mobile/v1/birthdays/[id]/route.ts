import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { familyBirthdays, profiles } from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { isProfileColor } from "@/lib/profile-colors";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);
const optionalText = z.string().trim().max(2000).nullable().optional();

const birthdayUpdateSchema = z.object({
  name: shortText.optional(),
  birthDate: z.string().date().optional(),
  kind: z.enum(["birthday", "anniversary"]).optional(),
  // Left out (as older apps do), the color stays as it was.
  color: z
    .string()
    .refine(isProfileColor, "Pick one of the listed colors.")
    .optional(),
  profileId: z.string().uuid().nullable().optional(),
  notes: optionalText,
  giftIdeas: optionalText,
  notifyDaysBefore: z.coerce.number().int().min(0).max(60).optional(),
});

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z
      .string()
      .uuid()
      .parse((await context.params).id);
    const input = birthdayUpdateSchema.parse(await parseJsonBody(request));

    const existing = await db
      .select()
      .from(familyBirthdays)
      .where(
        and(
          eq(familyBirthdays.id, id),
          eq(familyBirthdays.householdId, household.id)
        )
      )
      .limit(1);
    if (!existing[0]) throw new Error("Birthday not found.");

    const kind = input.kind ?? existing[0].kind;
    const birthDate = input.birthDate ?? existing[0].birthDate;
    if (birthDate > localDateIn(household.timezone)) {
      throw new Error(
        kind === "anniversary"
          ? "The anniversary date cannot be in the future."
          : "Birthday cannot be in the future."
      );
    }

    let profileId = existing[0].profileId;
    if (kind === "anniversary") {
      profileId = null;
    } else if (input.profileId !== undefined) {
      profileId = input.profileId;
      if (profileId) {
        const profile = await db
          .select({ id: profiles.id })
          .from(profiles)
          .where(
            and(
              eq(profiles.id, profileId),
              eq(profiles.householdId, household.id)
            )
          )
          .limit(1);
        if (!profile[0]) throw new Error("Profile not found.");
      }
    }

    const updated = await db
      .update(familyBirthdays)
      .set({
        name: input.name ?? existing[0].name,
        birthDate,
        kind,
        profileId,
        color: input.color ?? existing[0].color,
        notes: input.notes === undefined ? existing[0].notes : input.notes,
        giftIdeas:
          input.giftIdeas === undefined
            ? existing[0].giftIdeas
            : input.giftIdeas,
        notifyDaysBefore:
          input.notifyDaysBefore ?? existing[0].notifyDaysBefore,
        updatedAt: new Date(),
      })
      .where(eq(familyBirthdays.id, id))
      .returning();

    if (!updated[0]) throw new Error("Birthday not found.");
    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z
      .string()
      .uuid()
      .parse((await context.params).id);
    const deleted = await db
      .delete(familyBirthdays)
      .where(
        and(
          eq(familyBirthdays.id, id),
          eq(familyBirthdays.householdId, household.id)
        )
      )
      .returning({ id: familyBirthdays.id });
    if (!deleted[0]) throw new Error("Birthday not found.");
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
