import { and, eq, sql } from "drizzle-orm";
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

  const decision = evaluateMemberRoleChange({
    actorRole: input.actorRole,
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

  // Demoting an owner re-checks, inside the update itself, that another owner is left. The check above runs on
  // a list read a moment earlier, so two owners demoting each other at the same time both passed it and left the
  // household with none; a single statement is run on its own, so the second one sees the first one's result.
  const demotingOwner = target.role === "owner" && input.nextRole !== "owner";
  const updated = await db
    .update(householdMembers)
    .set({ role: input.nextRole })
    .where(
      and(
        eq(householdMembers.householdId, input.householdId),
        eq(householdMembers.userId, input.targetUserId),
        demotingOwner
          ? sql`(select count(*) from household_members as owners where owners.household_id = ${input.householdId} and owners.role = 'owner') > 1`
          : undefined,
      ),
    )
    .returning({ userId: householdMembers.userId });
  if (demotingOwner && updated.length === 0) {
    throw new Error("The household needs at least one owner.");
  }

  return input.nextRole;
}
