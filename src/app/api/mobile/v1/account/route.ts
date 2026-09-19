import { and, eq } from "drizzle-orm";
import { APIError } from "better-auth/api";
import { headers } from "next/headers";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { auth } from "@/lib/auth";
import { getLinkedProfile } from "@/lib/member-profiles";
import {
  handleMobileError,
  mobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

export async function GET() {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    const profile = await getLinkedProfile(household.id, user.id);
    return mobileJson({ user, profile });
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function PATCH(request: Request) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    const input = z
      .object({
        name: shortText.optional(),
      })
      .parse(await parseJsonBody(request));

    if (!input.name) {
      throw new Error("Nothing to update.");
    }

    const updatedUser = await auth.api.updateUser({
      body: { name: input.name },
      headers: await headers(),
    });

    await db
      .update(profiles)
      .set({ name: input.name, updatedAt: new Date() })
      .where(
        and(eq(profiles.householdId, household.id), eq(profiles.userId, user.id)),
      );

    const profile = await getLinkedProfile(household.id, user.id);
    return mobileJson({ user: updatedUser, profile });
  } catch (error) {
    return handleMobileError(error);
  }
}

const deleteAccountSchema = z.object({ password: z.string().min(1) });

/**
 * Permanently deletes the signed-in account after checking its password.
 * See detachUserFromHouseholds for what happens to the user's household.
 */
export async function DELETE(request: Request) {
  try {
    await requireMobileUser();
    const input = deleteAccountSchema.parse(await parseJsonBody(request));
    await auth.api.deleteUser({
      body: { password: input.password },
      headers: await headers(),
    });
    return mobileJson({ ok: true });
  } catch (error) {
    if (error instanceof APIError) {
      return mobileError(
        String(error.body?.message ?? "Could not delete the account."),
        error.statusCode,
      );
    }
    return handleMobileError(error);
  }
}
