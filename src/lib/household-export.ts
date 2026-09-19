import { asc, eq, inArray } from "drizzle-orm";
import { db } from "@/db/client";
import {
  choreCompletions,
  chores,
  familyBirthdays,
  groceryItems,
  householdMembers,
  householdNotes,
  households,
  meals,
  napLogs,
  profiles,
  recipes,
  routineCompletions,
  routines,
  routineSteps,
  snackCompletions,
  users,
} from "@/db/schema";
import { parseJsonArray } from "@/lib/recipes/store";

/**
 * Everything a household owns, as plain JSON a family can keep or move elsewhere.
 * Deliberately left out: invite codes, member email addresses, who completed what, passwords,
 * and sessions.
 */
export async function buildHouseholdExport(householdId: string) {
  const [household] = await db
    .select({
      name: households.name,
      timezone: households.timezone,
      weekStartsOn: households.weekStartsOn,
      snackOptions: households.snackOptions,
      weatherLocation: households.weatherLocation,
      createdAt: households.createdAt,
    })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  const [members, profileRows, routineRows, choreRows, recipeRows] =
    await Promise.all([
      db
        .select({
          name: users.name,
          role: householdMembers.role,
          joinedAt: householdMembers.joinedAt,
        })
        .from(householdMembers)
        .innerJoin(users, eq(householdMembers.userId, users.id))
        .where(eq(householdMembers.householdId, householdId)),
      db
        .select()
        .from(profiles)
        .where(eq(profiles.householdId, householdId))
        .orderBy(asc(profiles.sortOrder)),
      db
        .select()
        .from(routines)
        .where(eq(routines.householdId, householdId))
        .orderBy(asc(routines.sortOrder)),
      db
        .select()
        .from(chores)
        .where(eq(chores.householdId, householdId))
        .orderBy(asc(chores.sortOrder)),
      db.select().from(recipes).where(eq(recipes.householdId, householdId)),
    ]);

  const routineIds = routineRows.map((row) => row.id);
  const choreIds = choreRows.map((row) => row.id);

  const stepRows = routineIds.length
    ? await db
        .select()
        .from(routineSteps)
        .where(inArray(routineSteps.routineId, routineIds))
        .orderBy(asc(routineSteps.sortOrder))
    : [];
  const stepIds = stepRows.map((row) => row.id);

  const [
    routineCompletionRows,
    choreCompletionRows,
    snackRows,
    sleepRows,
    mealRows,
    groceryRows,
    noteRows,
    birthdayRows,
  ] = await Promise.all([
    stepIds.length
      ? db
          .select()
          .from(routineCompletions)
          .where(inArray(routineCompletions.stepId, stepIds))
      : [],
    choreIds.length
      ? db
          .select()
          .from(choreCompletions)
          .where(inArray(choreCompletions.choreId, choreIds))
      : [],
    db
      .select()
      .from(snackCompletions)
      .where(eq(snackCompletions.householdId, householdId)),
    db.select().from(napLogs).where(eq(napLogs.householdId, householdId)),
    db.select().from(meals).where(eq(meals.householdId, householdId)),
    db
      .select()
      .from(groceryItems)
      .where(eq(groceryItems.householdId, householdId)),
    db
      .select()
      .from(householdNotes)
      .where(eq(householdNotes.householdId, householdId)),
    db
      .select()
      .from(familyBirthdays)
      .where(eq(familyBirthdays.householdId, householdId)),
  ]);

  return {
    format: "beacon-household-export",
    version: 1,
    exportedAt: new Date().toISOString(),
    household,
    members,
    profiles: profileRows.map((row) => omit(row, "householdId")),
    routines: routineRows.map((row) => ({
      ...omit(row, "householdId"),
      steps: stepRows
        .filter((step) => step.routineId === row.id)
        .map((step) => omit(step, "routineId")),
    })),
    routineCompletions: routineCompletionRows.map((row) => omit(row, "completedBy")),
    chores: choreRows.map((row) => omit(row, "householdId")),
    choreCompletions: choreCompletionRows.map((row) => omit(row, "completedBy")),
    snackCompletions: snackRows.map((row) => omit(row, "householdId")),
    sleepLogs: sleepRows.map((row) => omit(row, "householdId")),
    recipes: recipeRows.map((row) => ({
      ...omit(row, "householdId"),
      ingredients: parseJsonArray(row.ingredients),
      directions: parseJsonArray(row.directions),
      tags: parseJsonArray(row.tags),
    })),
    meals: mealRows.map((row) => omit(row, "householdId")),
    groceryItems: groceryRows.map((row) => omit(row, "householdId")),
    notes: noteRows.map((row) => omit(row, "householdId", "createdByUserId")),
    birthdays: birthdayRows.map((row) => omit(row, "householdId")),
  };
}

function omit<T extends object, K extends keyof T>(row: T, ...keys: K[]) {
  const copy = { ...row };
  for (const key of keys) delete copy[key];
  return copy as Omit<T, K>;
}
