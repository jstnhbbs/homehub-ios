import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { familyBirthdays, profiles } from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { listHouseholdBirthdays } from "@/lib/family-birthdays";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);
const optionalText = z.string().trim().max(2000).optional();

const birthdayInputSchema = z.object({
  name: shortText,
  birthDate: z.string().date(),
  kind: z.enum(["birthday", "anniversary"]).default("birthday"),
  profileId: z.string().uuid().nullable().optional(),
  notes: optionalText,
  giftIdeas: optionalText,
  notifyDaysBefore: z.coerce.number().int().min(0).max(60).optional(),
});

async function loadBirthdayItems(householdId: string, timezone: string) {
  const [profileRows, familyRows] = await Promise.all([
    db
      .select({
        id: profiles.id,
        name: profiles.name,
        color: profiles.color,
        avatar: profiles.avatar,
        birthday: profiles.birthday,
      })
      .from(profiles)
      .where(eq(profiles.householdId, householdId))
      .orderBy(asc(profiles.sortOrder)),
    db
      .select()
      .from(familyBirthdays)
      .where(eq(familyBirthdays.householdId, householdId))
      .orderBy(asc(familyBirthdays.name)),
  ]);

  return listHouseholdBirthdays(
    profileRows,
    familyRows.map((row) => ({
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      birthDate: row.birthDate,
      kind: row.kind,
      notes: row.notes,
      giftIdeas: row.giftIdeas,
      notifyDaysBefore: row.notifyDaysBefore,
    })),
    localDateIn(timezone),
  );
}

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    return mobileJson({
      items: await loadBirthdayItems(household.id, household.timezone),
    });
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = birthdayInputSchema.parse(await parseJsonBody(request));
    const today = localDateIn(household.timezone);
    if (input.birthDate > today) {
      throw new Error(
        input.kind === "anniversary"
          ? "The anniversary date cannot be in the future."
          : "Birthday cannot be in the future.",
      );
    }

    // An anniversary belongs to a couple or a group, not to one profile.
    const profileId: string | null =
      input.kind === "anniversary" ? null : (input.profileId ?? null);
    if (profileId) {
      const profile = await db
        .select({ id: profiles.id })
        .from(profiles)
        .where(
          and(eq(profiles.id, profileId), eq(profiles.householdId, household.id)),
        )
        .limit(1);
      if (!profile[0]) throw new Error("Profile not found.");
    }

    const id = randomUUID();
    await db.insert(familyBirthdays).values({
      id,
      householdId: household.id,
      profileId,
      name: input.name,
      birthDate: input.birthDate,
      kind: input.kind,
      notes: input.notes?.trim() ? input.notes : null,
      giftIdeas: input.giftIdeas?.trim() ? input.giftIdeas : null,
      notifyDaysBefore: input.notifyDaysBefore ?? 7,
    });

    const items = await loadBirthdayItems(household.id, household.timezone);
    return mobileJson(
      {
        item: items.find((item) => item.id === id) ?? null,
        items,
      },
      201,
    );
  } catch (error) {
    return handleMobileError(error);
  }
}
