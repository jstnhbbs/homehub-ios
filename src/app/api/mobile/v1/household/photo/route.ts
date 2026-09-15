import { PROFILE_PHOTO_MAX_BYTES, PROFILE_PHOTO_TYPES } from "@/lib/profile-photo";
import {
  removeHouseholdPhoto,
  saveHouseholdPhoto,
  uploadHouseholdPhotoFile,
} from "@/lib/household-photo";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  getCurrentHousehold,
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
  requireMobileUser,
  serializeHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileParentHousehold();

    const allowed = await checkRateLimit("household-photo-upload", user.id, {
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
    const url = await uploadHouseholdPhotoFile({
      householdId: household.id,
      fileName: file.name || "photo.jpg",
      contentType: file.type,
      data: buffer,
    });

    await saveHouseholdPhoto({
      householdId: household.id,
      url,
    });

    const updated = await getCurrentHousehold();
    if (!updated) throw new Error("Household not found.");
    return mobileJson(serializeHousehold(updated));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE() {
  try {
    const household = await requireMobileParentHousehold();
    await removeHouseholdPhoto(household.id);

    const updated = await getCurrentHousehold();
    if (!updated) throw new Error("Household not found.");
    return mobileJson(serializeHousehold(updated));
  } catch (error) {
    return handleMobileError(error);
  }
}
