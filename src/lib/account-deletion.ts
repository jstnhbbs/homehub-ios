import { and, eq, ne } from "drizzle-orm";
import { db } from "@/db/client";
import { householdMembers, households, profiles } from "@/db/schema";
import { UserFacingError } from "@/lib/errors";
import { removeHouseholdPhoto } from "@/lib/household-photo";
import { removeProfilePhotoForHousehold } from "@/lib/profile-photo";
import { deleteAllRecipeImages } from "@/lib/recipes/image";

export class AccountDeletionBlockedError extends UserFacingError {}

/**
 * Detaches a user from their households ahead of deleting the account.
 *
 * - The only owner of a household that still has other members must transfer ownership first.
 * - A sole member takes the whole household (and everything in it) with them.
 * - Anyone else just leaves: their membership and linked profile are removed, the household stays.
 *
 * Throws AccountDeletionBlockedError before changing anything if deletion is not allowed.
 */
export async function detachUserFromHouseholds(userId: string) {
  const memberships = await db
    .select()
    .from(householdMembers)
    .where(eq(householdMembers.userId, userId));

  const plans = await Promise.all(
    memberships.map(async (membership) => {
      const others = await db
        .select({ role: householdMembers.role })
        .from(householdMembers)
        .where(
          and(
            eq(householdMembers.householdId, membership.householdId),
            ne(householdMembers.userId, userId),
          ),
        );
      const otherOwnerExists = others.some((other) => other.role === "owner");
      if (membership.role === "owner" && others.length > 0 && !otherOwnerExists) {
        throw new AccountDeletionBlockedError(
          "You are the only owner of this household. Make another member an owner in Settings before deleting your account.",
        );
      }
      return { householdId: membership.householdId, deleteHousehold: others.length === 0 };
    }),
  );

  for (const plan of plans) {
    if (plan.deleteHousehold) {
      await deleteHousehold(plan.householdId);
    } else {
      await leaveHousehold(plan.householdId, userId);
    }
  }
}

async function deleteHousehold(householdId: string) {
  const familyProfiles = await db
    .select({ id: profiles.id })
    .from(profiles)
    .where(eq(profiles.householdId, householdId));
  for (const profile of familyProfiles) {
    await removeProfilePhotoForHousehold({ householdId, profileId: profile.id }).catch(
      () => undefined,
    );
  }
  await removeHouseholdPhoto(householdId).catch(() => undefined);
  await deleteAllRecipeImages(householdId);

  // Everything the household owns is removed by foreign-key cascades.
  await db.delete(households).where(eq(households.id, householdId));
}

async function leaveHousehold(householdId: string, userId: string) {
  const linked = await db
    .select({ id: profiles.id })
    .from(profiles)
    .where(and(eq(profiles.householdId, householdId), eq(profiles.userId, userId)));
  for (const profile of linked) {
    await removeProfilePhotoForHousehold({ householdId, profileId: profile.id }).catch(
      () => undefined,
    );
  }

  await db.transaction(async (tx) => {
    await tx
      .delete(profiles)
      .where(and(eq(profiles.householdId, householdId), eq(profiles.userId, userId)));
    await tx
      .delete(householdMembers)
      .where(
        and(eq(householdMembers.householdId, householdId), eq(householdMembers.userId, userId)),
      );
  });
}
