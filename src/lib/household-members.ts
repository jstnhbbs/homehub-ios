import { and, eq } from "drizzle-orm";
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

  await db
    .update(householdMembers)
    .set({ role: input.nextRole })
    .where(
      and(
        eq(householdMembers.householdId, input.householdId),
        eq(householdMembers.userId, input.targetUserId),
      ),
    );

  return input.nextRole;
}
