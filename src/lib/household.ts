import { and, asc, eq, sql } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { db } from "@/db/client";
import { householdMembers, households, users } from "@/db/schema";
import { auth } from "@/lib/auth";
import { canManageHousehold } from "@/lib/household-roles";
import { ensureMemberProfiles } from "@/lib/member-profiles";

export async function getSession() {
  return auth.api.getSession({ headers: await headers() });
}

export async function requireUser() {
  const session = await getSession();
  if (!session) redirect("/sign-in");
  return session.user;
}

/**
 * The caller's household with their role and the owner's name. Pass `userId` when the session was
 * already read (the mobile helpers do) so this does not look it up a second time.
 */
export async function getCurrentHousehold(knownUserId?: string) {
  const userId = knownUserId ?? (await getSession())?.user.id;
  if (!userId) return null;

  // One query: the owner's name rides along as a subquery instead of a second round trip.
  const result = await db
    .select({
      id: households.id,
      name: households.name,
      timezone: households.timezone,
      weekStartsOn: households.weekStartsOn,
      inviteCode: households.inviteCode,
      guestInviteCode: households.guestInviteCode,
      snackOptions: households.snackOptions,
      snacksPerChild: households.snacksPerChild,
      photo: households.photo,
      role: householdMembers.role,
      ownerName: sql<string | null>`(
        select ${users.name}
        from ${householdMembers} as owner_member
        inner join ${users} on ${users.id} = owner_member.user_id
        where owner_member.household_id = ${households.id}
          and owner_member.role = 'owner'
        limit 1
      )`,
    })
    .from(householdMembers)
    .innerJoin(households, eq(householdMembers.householdId, households.id))
    .where(eq(householdMembers.userId, userId))
    // A user can belong to more than one household; pick the same one every time.
    .orderBy(asc(householdMembers.joinedAt), asc(householdMembers.householdId))
    .limit(1);

  return result[0] ?? null;
}

export async function requireHousehold() {
  const user = await requireUser();
  const household = await getCurrentHousehold(user.id);
  if (!household) redirect("/onboarding");
  await ensureMemberProfiles(household.id);
  return household;
}

export async function requireParentHousehold() {
  const household = await requireHousehold();
  if (!canManageHousehold(household.role)) {
    throw new Error("You do not have permission to do that.");
  }
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
