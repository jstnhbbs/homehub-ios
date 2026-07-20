import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { canManageHousehold, type HouseholdRole } from "@/lib/household-roles";

export async function getHouseholdProfile(profileId: string, householdId: string) {
  const rows = await db
    .select()
    .from(profiles)
    .where(
      and(eq(profiles.id, profileId), eq(profiles.householdId, householdId)),
    )
    .limit(1);
  return rows[0] ?? null;
}

export function canEditProfilePhoto(input: {
  role: HouseholdRole;
  userId: string;
  profileUserId: string | null;
}) {
  if (canManageHousehold(input.role)) return true;
  return input.profileUserId === input.userId;
}

export async function assertCanEditProfilePhoto(input: {
  profileId: string;
  householdId: string;
  role: HouseholdRole;
  userId: string;
}) {
  const profile = await getHouseholdProfile(input.profileId, input.householdId);
  if (!profile) throw new Error("Family profile not found.");
  if (
    !canEditProfilePhoto({
      role: input.role,
      userId: input.userId,
      profileUserId: profile.userId,
    })
  ) {
    throw new Error("You do not have permission to do that.");
  }
  return profile;
}
