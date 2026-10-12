import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { householdMembers, profiles, users } from "@/db/schema";
import { GUEST_PROFILE_COLOR, pickProfileColor } from "@/lib/profile-colors";

export async function ensureMemberProfiles(householdId: string) {
  const members = await db
    .select({
      userId: householdMembers.userId,
      role: householdMembers.role,
      name: users.name,
      profileId: profiles.id,
    })
    .from(householdMembers)
    .innerJoin(users, eq(householdMembers.userId, users.id))
    .leftJoin(
      profiles,
      and(
        eq(profiles.householdId, householdMembers.householdId),
        eq(profiles.userId, householdMembers.userId),
      ),
    )
    .where(eq(householdMembers.householdId, householdId));

  // Each new profile takes the first color nobody in the household has, including the ones made just before it.
  // A guest starts with the quiet grey instead, so they don't use up one of the family's colors.
  const used: Array<string | null> = (
    await db.select({ color: profiles.color }).from(profiles).where(eq(profiles.householdId, householdId))
  ).map((row) => row.color);
  const missingProfiles = members
    .filter((member) => !member.profileId)
    .map((member, index) => {
      const color = member.role === "guest" ? GUEST_PROFILE_COLOR.value : pickProfileColor(used);
      used.push(color);
      return {
        id: randomUUID(),
        householdId,
        userId: member.userId,
        profileType: "adult" as const,
        name: member.name,
        color,
        sortOrder: -100 + index,
      };
    });

  if (missingProfiles.length > 0) {
    await db.insert(profiles).values(missingProfiles).onConflictDoNothing();
  }
}

export async function getLinkedProfile(householdId: string, userId: string) {
  const rows = await db
    .select()
    .from(profiles)
    .where(
      and(eq(profiles.householdId, householdId), eq(profiles.userId, userId)),
    )
    .limit(1);
  return rows[0] ?? null;
}
