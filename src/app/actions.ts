"use server";

import { randomBytes, randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { addDays, format, parseISO, subWeeks } from "date-fns";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { db } from "@/db/client";
import {
  choreCompletions,
  chores,
  householdMembers,
  households,
  meals,
  profiles,
  recipes,
  routineCompletions,
  routines,
  routineSteps,
} from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { isGuest } from "@/lib/household-roles";
import {
  requireHousehold,
  requireParentHousehold,
  requireUser,
} from "@/lib/household";
import { isProfileColor } from "@/lib/profile-colors";
import {
  removeProfilePhotoForHousehold,
  saveProfilePhotoForHousehold,
} from "@/lib/profile-photo";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

const shortText = z.string().trim().min(1).max(120);

function generateInviteCode() {
  return randomBytes(4).toString("hex").toUpperCase();
}

export async function createHousehold(formData: FormData) {
  const user = await requireUser();
  const input = z
    .object({
      name: shortText,
      childName: z.string().trim().max(60),
      timezone: z.string().trim().min(1).max(80),
    })
    .parse({
      name: text(formData, "name"),
      childName: text(formData, "childName"),
      timezone: text(formData, "timezone") || "America/Chicago",
    });

  const id = randomUUID();
  const inviteCode = generateInviteCode();
  let guestInviteCode = generateInviteCode();
  while (guestInviteCode === inviteCode) {
    guestInviteCode = generateInviteCode();
  }
  await db.transaction(async (tx) => {
    await tx.insert(households).values({
      id,
      name: input.name,
      timezone: input.timezone,
      inviteCode,
      guestInviteCode,
    });
    await tx.insert(householdMembers).values({
      householdId: id,
      userId: user.id,
      role: "owner",
    });
    if (input.childName) {
      await tx.insert(profiles).values({
        id: randomUUID(),
        householdId: id,
        name: input.childName,
        color: "#d87861",
      });
    }
  });
  redirect("/dashboard");
}

export async function joinHousehold(formData: FormData) {
  const user = await requireUser();
  const inviteCode = text(formData, "inviteCode").toUpperCase();
  const household = await db
    .select({ id: households.id })
    .from(households)
    .where(eq(households.inviteCode, inviteCode))
    .limit(1);
  if (!household[0]) throw new Error("That invite code was not found.");
  await db
    .insert(householdMembers)
    .values({
      householdId: household[0].id,
      userId: user.id,
      role: "parent",
    })
    .onConflictDoNothing();
  redirect("/dashboard");
}

export async function joinHouseholdAsGuest(formData: FormData) {
  const user = await requireUser();
  const inviteCode = text(formData, "guestInviteCode").toUpperCase();
  const household = await db
    .select({ id: households.id })
    .from(households)
    .where(eq(households.guestInviteCode, inviteCode))
    .limit(1);
  if (!household[0]) throw new Error("That guest invite code was not found.");
  await db
    .insert(householdMembers)
    .values({
      householdId: household[0].id,
      userId: user.id,
      role: "guest",
    })
    .onConflictDoNothing();
  redirect("/dashboard");
}

export async function removeGuestMember(formData: FormData) {
  const household = await requireParentHousehold();
  const userId = z.string().parse(formData.get("userId"));
  const member = await db
    .select({ role: householdMembers.role })
    .from(householdMembers)
    .where(
      and(
        eq(householdMembers.householdId, household.id),
        eq(householdMembers.userId, userId),
      ),
    )
    .limit(1);
  if (!member[0] || !isGuest(member[0].role)) {
    throw new Error("Only guest members can be removed here.");
  }
  await db
    .delete(householdMembers)
    .where(
      and(
        eq(householdMembers.householdId, household.id),
        eq(householdMembers.userId, userId),
      ),
    );
  revalidatePath("/", "layout");
}

export async function addProfile(formData: FormData) {
  const household = await requireParentHousehold();
  const name = shortText.parse(text(formData, "name"));
  const color = z
    .string()
    .refine(isProfileColor)
    .parse(text(formData, "color") || "#6689a3");
  const profileType = z
    .enum(["adult", "child"])
    .parse(text(formData, "profileType") || "child");
  await db.insert(profiles).values({
    id: randomUUID(),
    householdId: household.id,
    name,
    color,
    profileType,
  });
  revalidatePath("/", "layout");
}

export async function updateProfile(profileId: string, formData: FormData) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(profileId);
  const birthdayValue = text(formData, "birthday");
  const input = z
    .object({
      name: shortText,
      color: z.string().refine(isProfileColor, "Choose a valid profile color."),
      birthday: z.iso.date().nullable(),
      profileType: z.enum(["adult", "child"]),
    })
    .parse({
      name: text(formData, "name"),
      color: text(formData, "color"),
      birthday: birthdayValue || null,
      profileType: text(formData, "profileType"),
    });

  if (
    input.birthday &&
    input.birthday > localDateIn(household.timezone)
  ) {
    throw new Error("Birthday cannot be in the future.");
  }

  const existingProfile = await db
    .select({ userId: profiles.userId })
    .from(profiles)
    .where(
      and(
        eq(profiles.id, id),
        eq(profiles.householdId, household.id),
      ),
    )
    .limit(1);
  if (!existingProfile[0]) throw new Error("Profile not found.");

  await db
    .update(profiles)
    .set({
      name: input.name,
      color: input.color,
      birthday: input.birthday,
      profileType: existingProfile[0].userId ? "adult" : input.profileType,
      updatedAt: new Date(),
    })
    .where(
      and(
        eq(profiles.id, id),
        eq(profiles.householdId, household.id),
      ),
    );

  revalidatePath("/", "layout");
  redirect("/settings");
}

export async function setProfilePhoto(profileId: string, url: string) {
  const household = await requireParentHousehold();
  await saveProfilePhotoForHousehold({
    householdId: household.id,
    profileId: z.string().uuid().parse(profileId),
    url: z.string().url().parse(url),
  });
  revalidatePath("/", "layout");
}

export async function removeProfilePhoto(profileId: string) {
  const household = await requireParentHousehold();
  await removeProfilePhotoForHousehold({
    householdId: household.id,
    profileId: z.string().uuid().parse(profileId),
  });
  revalidatePath("/", "layout");
}

export async function addRoutine(formData: FormData) {
  const household = await requireParentHousehold();
  const input = z
    .object({
      name: shortText,
      profileId: z.string().uuid().optional(),
      period: z.enum(["morning", "afternoon", "evening"]),
      steps: z.array(shortText).min(1).max(20),
    })
    .parse({
      name: text(formData, "name"),
      profileId: text(formData, "profileId") || undefined,
      period: text(formData, "period"),
      steps: text(formData, "steps")
        .split("\n")
        .map((step) => step.trim())
        .filter(Boolean),
    });
  if (input.profileId) {
    const profile = await db
      .select({ id: profiles.id })
      .from(profiles)
      .where(
        and(
          eq(profiles.id, input.profileId),
          eq(profiles.householdId, household.id),
        ),
      )
      .limit(1);
    if (!profile[0]) throw new Error("Invalid family profile.");
  }
  const routineId = randomUUID();
  await db.transaction(async (tx) => {
    await tx.insert(routines).values({
      id: routineId,
      householdId: household.id,
      profileId: input.profileId,
      name: input.name,
      period: input.period,
    });
    await tx.insert(routineSteps).values(
      input.steps.map((label, index) => ({
        id: randomUUID(),
        routineId,
        label,
        sortOrder: index,
      })),
    );
  });
  revalidatePath("/", "layout");
}

export async function updateRoutine(routineId: string, formData: FormData) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(routineId);
  const input = z
    .object({
      name: shortText,
      profileId: z.string().uuid().optional(),
      period: z.enum(["morning", "afternoon", "evening"]),
      steps: z.array(shortText).min(1).max(20),
    })
    .parse({
      name: text(formData, "name"),
      profileId: text(formData, "profileId") || undefined,
      period: text(formData, "period"),
      steps: text(formData, "steps")
        .split("\n")
        .map((step) => step.trim())
        .filter(Boolean),
    });
  const routine = await db
    .select({ id: routines.id })
    .from(routines)
    .where(
      and(
        eq(routines.id, id),
        eq(routines.householdId, household.id),
      ),
    )
    .limit(1);
  if (!routine[0]) throw new Error("Routine not found.");
  if (input.profileId) {
    const profile = await db
      .select({ id: profiles.id })
      .from(profiles)
      .where(
        and(
          eq(profiles.id, input.profileId),
          eq(profiles.householdId, household.id),
        ),
      )
      .limit(1);
    if (!profile[0]) throw new Error("Invalid family profile.");
  }

  await db.transaction(async (tx) => {
    await tx
      .update(routines)
      .set({
        name: input.name,
        profileId: input.profileId ?? null,
        period: input.period,
        updatedAt: new Date(),
      })
      .where(eq(routines.id, id));
    const existingSteps = await tx
      .select({ id: routineSteps.id })
      .from(routineSteps)
      .where(eq(routineSteps.routineId, id))
      .orderBy(asc(routineSteps.sortOrder));

    for (const [index, label] of input.steps.entries()) {
      const existingStep = existingSteps[index];
      if (existingStep) {
        await tx
          .update(routineSteps)
          .set({ label, sortOrder: index })
          .where(eq(routineSteps.id, existingStep.id));
      } else {
        await tx.insert(routineSteps).values({
          id: randomUUID(),
          routineId: id,
          label,
          sortOrder: index,
        });
      }
    }
    for (const removedStep of existingSteps.slice(input.steps.length)) {
      await tx
        .delete(routineSteps)
        .where(eq(routineSteps.id, removedStep.id));
    }
  });
  revalidatePath("/", "layout");
}

export async function toggleRoutineStep(
  stepId: string,
  localDate: string,
  completed: boolean,
) {
  const household = await requireHousehold();
  const step = await db
    .select({ id: routineSteps.id })
    .from(routineSteps)
    .innerJoin(routines, eq(routineSteps.routineId, routines.id))
    .where(
      and(
        eq(routineSteps.id, stepId),
        eq(routines.householdId, household.id),
      ),
    )
    .limit(1);
  if (!step[0]) throw new Error("Routine step not found.");

  if (completed) {
    await db
      .insert(routineCompletions)
      .values({ stepId, localDate })
      .onConflictDoNothing();
  } else {
    await db
      .delete(routineCompletions)
      .where(
        and(
          eq(routineCompletions.stepId, stepId),
          eq(routineCompletions.localDate, localDate),
        ),
      );
  }
  revalidatePath("/", "layout");
}

export async function addChore(formData: FormData) {
  const household = await requireParentHousehold();
  const input = z
    .object({
      title: shortText,
      profileId: z.string().uuid().optional(),
      cadence: z.enum(["daily", "weekly"]),
    })
    .parse({
      title: text(formData, "title"),
      profileId: text(formData, "profileId") || undefined,
      cadence: text(formData, "cadence") || "daily",
    });
  await db.insert(chores).values({
    id: randomUUID(),
    householdId: household.id,
    ...input,
  });
  revalidatePath("/", "layout");
}

export async function updateChore(choreId: string, formData: FormData) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(choreId);
  const input = z
    .object({
      title: shortText,
      profileId: z.string().uuid().optional(),
      cadence: z.enum(["daily", "weekly"]),
    })
    .parse({
      title: text(formData, "title"),
      profileId: text(formData, "profileId") || undefined,
      cadence: text(formData, "cadence"),
    });
  const chore = await db
    .select({ id: chores.id })
    .from(chores)
    .where(
      and(
        eq(chores.id, id),
        eq(chores.householdId, household.id),
      ),
    )
    .limit(1);
  if (!chore[0]) throw new Error("Chore not found.");
  if (input.profileId) {
    const profile = await db
      .select({ id: profiles.id })
      .from(profiles)
      .where(
        and(
          eq(profiles.id, input.profileId),
          eq(profiles.householdId, household.id),
        ),
      )
      .limit(1);
    if (!profile[0]) throw new Error("Invalid family profile.");
  }

  await db
    .update(chores)
    .set({
      title: input.title,
      profileId: input.profileId ?? null,
      cadence: input.cadence,
      updatedAt: new Date(),
    })
    .where(eq(chores.id, id));
  revalidatePath("/", "layout");
}

export async function deleteChore(choreId: string) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(choreId);
  const deleted = await db
    .delete(chores)
    .where(
      and(
        eq(chores.id, id),
        eq(chores.householdId, household.id),
      ),
    )
    .returning({ id: chores.id });
  if (!deleted[0]) throw new Error("Chore not found.");
  revalidatePath("/", "layout");
}

export async function toggleChore(
  choreId: string,
  periodKey: string,
  completed: boolean,
) {
  const household = await requireHousehold();
  const chore = await db
    .select({ id: chores.id })
    .from(chores)
    .where(and(eq(chores.id, choreId), eq(chores.householdId, household.id)))
    .limit(1);
  if (!chore[0]) throw new Error("Chore not found.");
  if (completed) {
    await db
      .insert(choreCompletions)
      .values({ choreId, periodKey })
      .onConflictDoNothing();
  } else {
    await db
      .delete(choreCompletions)
      .where(
        and(
          eq(choreCompletions.choreId, choreId),
          eq(choreCompletions.periodKey, periodKey),
        ),
      );
  }
  revalidatePath("/", "layout");
}

export async function saveMeal(formData: FormData) {
  const household = await requireParentHousehold();
  const recipeIdValue = text(formData, "recipeId");
  const input = z
    .object({
      localDate: z.string().date(),
      slot: z.enum(["breakfast", "lunch", "dinner", "snack"]),
      title: z.string().trim().max(120),
      recipeId: z.string().uuid().optional(),
    })
    .parse({
      localDate: text(formData, "localDate"),
      slot: text(formData, "slot"),
      title: text(formData, "title"),
      recipeId: recipeIdValue || undefined,
    });

  if (!input.title) {
    await db
      .delete(meals)
      .where(
        and(
          eq(meals.householdId, household.id),
          eq(meals.localDate, input.localDate),
          eq(meals.slot, input.slot),
        ),
      );
  } else {
    let recipeId = input.recipeId ?? null;
    let title = input.title;
    if (recipeId) {
      const recipe = await db
        .select({ id: recipes.id, title: recipes.title })
        .from(recipes)
        .where(
          and(
            eq(recipes.id, recipeId),
            eq(recipes.householdId, household.id),
          ),
        )
        .limit(1);
      if (!recipe[0]) {
        recipeId = null;
      } else {
        title = recipe[0].title;
      }
    }

    await db
      .insert(meals)
      .values({
        id: randomUUID(),
        householdId: household.id,
        localDate: input.localDate,
        slot: input.slot,
        title,
        recipeId,
      })
      .onConflictDoUpdate({
        target: [meals.householdId, meals.localDate, meals.slot],
        set: { title, recipeId, updatedAt: new Date() },
      });
  }
  revalidatePath("/", "layout");
}

export async function clearMealWeek(formData: FormData) {
  const household = await requireParentHousehold();
  const start = parseISO(z.string().date().parse(text(formData, "weekStart")));
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
  revalidatePath("/", "layout");
}

export async function copyPreviousMealWeek(formData: FormData) {
  const household = await requireParentHousehold();
  const start = parseISO(z.string().date().parse(text(formData, "weekStart")));
  const priorStart = subWeeks(start, 1);
  const priorMeals = await db
    .select()
    .from(meals)
    .where(eq(meals.householdId, household.id));
  const sourceDates = new Map(
    Array.from({ length: 7 }, (_, index) => [
      format(addDays(priorStart, index), "yyyy-MM-dd"),
      format(addDays(start, index), "yyyy-MM-dd"),
    ]),
  );
  for (const meal of priorMeals) {
    const targetDate = sourceDates.get(meal.localDate);
    if (!targetDate) continue;
    await db
      .insert(meals)
      .values({
        id: randomUUID(),
        householdId: household.id,
        localDate: targetDate,
        slot: meal.slot,
        title: meal.title,
        recipeId: meal.recipeId,
        notes: meal.notes,
      })
      .onConflictDoUpdate({
        target: [meals.householdId, meals.localDate, meals.slot],
        set: {
          title: meal.title,
          recipeId: meal.recipeId,
          notes: meal.notes,
          updatedAt: new Date(),
        },
      });
  }
  revalidatePath("/", "layout");
}
