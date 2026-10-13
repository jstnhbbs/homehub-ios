import { and, eq, or, ne, sql } from "drizzle-orm";
import { db } from "@/db/client";
import { householdMembers } from "@/db/schema";
import {
  evaluateMemberRoleChange,
  type HouseholdRole,
} from "@/lib/household-roles";

export async function updateHouseholdMemberRole(input: {
  householdId: string;
  actorUserId: string;
  actorRole: HouseholdRole;
  targetUserId: string;
  nextRole: HouseholdRole;
}) {
  const members = await db
    .select({
      userId: householdMembers.userId,
      role: householdMembers.role,
    })
    .from(householdMembers)
    .where(eq(householdMembers.householdId, input.householdId));

  const target = members.find((member) => member.userId === input.targetUserId);
  if (!target) {
    throw new Error("Member not found.");
  }
  const actor = members.find((member) => member.userId === input.actorUserId);
  if (!actor) throw new Error("You do not have permission to do that.");

  const decision = evaluateMemberRoleChange({
    actorRole: actor.role,
    actorUserId: input.actorUserId,
    targetUserId: input.targetUserId,
    targetRole: target.role,
    nextRole: input.nextRole,
    ownerCount: members.filter((member) => member.role === "owner").length,
  });
  if (!decision.ok) {
    throw new Error(decision.error);
  }
  if (target.role === input.nextRole) {
    return target.role;
  }

  // Both roles may change after the read. Enforce permission and the last-owner invariant on the rows
  // as they are when this statement runs, including a target promoted since the read.
  const updated = await db
    .update(householdMembers)
    .set({ role: input.nextRole })
    .where(
      and(
        eq(householdMembers.householdId, input.householdId),
        eq(householdMembers.userId, input.targetUserId),
        sql`exists (select 1 from household_members as actor
          where actor.household_id = ${input.householdId} and actor.user_id = ${input.actorUserId}
          and (actor.role = 'owner' or
            (actor.role = 'parent' and ${householdMembers.role} != 'owner' and ${input.nextRole} != 'owner')))`,
        input.nextRole !== "owner"
          ? or(
              ne(householdMembers.role, "owner"),
              sql`(select count(*) from household_members as owners where owners.household_id = ${input.householdId} and owners.role = 'owner') > 1`,
            )
          : undefined,
      ),
    )
    .returning({ userId: householdMembers.userId });
  if (updated.length === 0) {
    throw new Error("Member roles changed or the household needs at least one owner. Refresh and try again.");
  }

  return input.nextRole;
}
