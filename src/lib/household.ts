import { and, eq } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { db } from "@/db/client";
import { householdMembers, households } from "@/db/schema";
import { auth } from "@/lib/auth";

export async function getSession() {
  return auth.api.getSession({ headers: await headers() });
}

export async function requireUser() {
  const session = await getSession();
  if (!session) redirect("/sign-in");
  return session.user;
}

export async function getCurrentHousehold() {
  const session = await getSession();
  if (!session) return null;

  const result = await db
    .select({
      id: households.id,
      name: households.name,
      timezone: households.timezone,
      inviteCode: households.inviteCode,
      role: householdMembers.role,
    })
    .from(householdMembers)
    .innerJoin(households, eq(householdMembers.householdId, households.id))
    .where(eq(householdMembers.userId, session.user.id))
    .limit(1);

  return result[0] ?? null;
}

export async function requireHousehold() {
  await requireUser();
  const household = await getCurrentHousehold();
  if (!household) redirect("/onboarding");
  return household;
}

export async function assertHouseholdAccess(householdId: string) {
  const user = await requireUser();
  const membership = await db
    .select({ householdId: householdMembers.householdId })
    .from(householdMembers)
    .where(
      and(
        eq(householdMembers.householdId, householdId),
        eq(householdMembers.userId, user.id),
      ),
    )
    .limit(1);

  if (!membership[0]) throw new Error("Household access denied");
  return user;
}
