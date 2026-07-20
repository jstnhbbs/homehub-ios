import { and, eq } from "drizzle-orm";
import { headers } from "next/headers";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { auth } from "@/lib/auth";
import { localDateIn } from "@/lib/dates";
import { canManageHousehold } from "@/lib/household-roles";
import { isProfileColor } from "@/lib/profile-colors";
import {
  handleMobileError,
  mobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const input = z
      .object({
        name: shortText,
        profileType: z.enum(["adult", "child"]),
        color: z.string(),
        birthday: z.string().date().nullable().optional(),
      })
      .parse(await parseJsonBody(request));

    if (!isProfileColor(input.color)) {
      throw new Error("Invalid profile color.");
    }

    const existing = await db
      .select()
      .from(profiles)
      .where(
        and(eq(profiles.id, id), eq(profiles.householdId, household.id)),
      )
      .limit(1);
    if (!existing[0]) throw new Error("Profile not found.");

    const canManage = canManageHousehold(household.role);
    const isOwnProfile = existing[0].userId === user.id;
    if (!canManage && !isOwnProfile) {
      throw mobileError("You do not have permission to do that.", 403);
    }

    if (
      input.birthday &&
      input.birthday > localDateIn(household.timezone)
    ) {
      throw new Error("Birthday cannot be in the future.");
    }

    const profileType = existing[0].userId
      ? "adult"
      : canManage
        ? input.profileType
        : existing[0].profileType;

    const updated = await db
      .update(profiles)
      .set({
        name: input.name,
        profileType,
        color: input.color,
        birthday: input.birthday ?? null,
        updatedAt: new Date(),
      })
      .where(and(eq(profiles.id, id), eq(profiles.householdId, household.id)))
      .returning();

    if (isOwnProfile && existing[0].userId) {
      await auth.api.updateUser({
        body: { name: input.name },
        headers: await headers(),
      });
    }

    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}
