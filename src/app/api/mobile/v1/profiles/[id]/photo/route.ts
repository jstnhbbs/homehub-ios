import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { checkRateLimit } from "@/lib/rate-limit";
import { assertCanEditProfilePhoto } from "@/lib/profile-photo-access";
import {
  PROFILE_PHOTO_MAX_BYTES,
  PROFILE_PHOTO_TYPES,
  removeProfilePhotoForHousehold,
  saveProfilePhotoForHousehold,
  uploadProfilePhotoFile,
} from "@/lib/profile-photo";
import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    const profileId = z.string().uuid().parse((await context.params).id);

    await assertCanEditProfilePhoto({
      profileId,
      householdId: household.id,
      role: household.role,
      userId: user.id,
    });

    const allowed = await checkRateLimit("profile-photo-upload", user.id, {
      limit: 20,
      windowMs: 15 * 60 * 1000,
    });
    if (!allowed) throw new Error("Too many upload attempts.");

    const formData = await request.formData();
    const file = formData.get("file");
    if (!(file instanceof File)) {
      throw new Error("Photo file is required.");
    }
    if (
      !PROFILE_PHOTO_TYPES.includes(
        file.type as (typeof PROFILE_PHOTO_TYPES)[number],
      )
    ) {
      throw new Error("Choose a JPEG, PNG, or WebP image.");
    }
    if (file.size > PROFILE_PHOTO_MAX_BYTES) {
      throw new Error("Choose an image smaller than 5 MB.");
    }

    const buffer = Buffer.from(await file.arrayBuffer());
    const url = await uploadProfilePhotoFile({
      profileId,
      fileName: file.name || "photo.jpg",
      contentType: file.type,
      data: buffer,
    });

    await saveProfilePhotoForHousehold({
      householdId: household.id,
      profileId,
      url,
    });

    const updated = await db
      .select()
      .from(profiles)
      .where(
        and(eq(profiles.id, profileId), eq(profiles.householdId, household.id)),
      )
      .limit(1);

    if (!updated[0]) throw new Error("Family profile not found.");
    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileHousehold();
    const profileId = z.string().uuid().parse((await context.params).id);

    await assertCanEditProfilePhoto({
      profileId,
      householdId: household.id,
      role: household.role,
      userId: user.id,
    });

    await removeProfilePhotoForHousehold({
      householdId: household.id,
      profileId,
    });

    const updated = await db
      .select()
      .from(profiles)
      .where(
        and(eq(profiles.id, profileId), eq(profiles.householdId, household.id)),
      )
      .limit(1);

    if (!updated[0]) throw new Error("Family profile not found.");
    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}
