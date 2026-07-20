import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { householdMembers, profiles, users } from "@/db/schema";

export async function ensureMemberProfiles(householdId: string) {
  const members = await db
    .select({
      userId: householdMembers.userId,
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

  const missingProfiles = members
    .filter((member) => !member.profileId)
    .map((member, index) => ({
      id: randomUUID(),
      householdId,
      userId: member.userId,
      profileType: "adult" as const,
      name: member.name,
      color: "#6689a3",
      sortOrder: -100 + index,
    }));

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
