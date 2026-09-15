import { del, head, put } from "@vercel/blob";
import { mkdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import {
  PROFILE_PHOTO_MAX_BYTES,
  PROFILE_PHOTO_TYPES,
} from "@/lib/profile-photo";
import {
  hasHouseholdPhoto,
  isManagedHouseholdPhoto,
  looksLikeLocalHouseholdPhoto,
} from "@/lib/household-photo-url";

export { hasHouseholdPhoto };

type HouseholdPhotoType = (typeof PROFILE_PHOTO_TYPES)[number];

function isLocalDevHouseholdPhoto(url: string, householdId: string) {
  return (
    process.env.NODE_ENV === "development" &&
    looksLikeLocalHouseholdPhoto(url, householdId)
  );
}

function isValidHouseholdPhotoUrl(url: string, householdId: string) {
  return (
    isManagedHouseholdPhoto(url, householdId) ||
    isLocalDevHouseholdPhoto(url, householdId)
  );
}

export async function uploadHouseholdPhotoFile(input: {
  householdId: string;
  fileName: string;
  contentType: string;
  data: Buffer;
}) {
  if (!PROFILE_PHOTO_TYPES.includes(input.contentType as HouseholdPhotoType)) {
    throw new Error("Choose a JPEG, PNG, or WebP image.");
  }
  if (input.data.byteLength > PROFILE_PHOTO_MAX_BYTES) {
    throw new Error("Choose an image smaller than 5 MB.");
  }

  const safeName = input.fileName.replace(/[^a-zA-Z0-9._-]/g, "-");
  const pathname = `households/${input.householdId}/${Date.now()}-${safeName}`;

  if (process.env.BLOB_READ_WRITE_TOKEN) {
    const blob = await put(pathname, input.data, {
      access: "public",
      contentType: input.contentType,
      addRandomSuffix: true,
      cacheControlMaxAge: 60 * 60 * 24 * 30,
    });
    return blob.url;
  }

  if (process.env.NODE_ENV === "development") {
    const extension =
      input.contentType === "image/png"
        ? "png"
        : input.contentType === "image/webp"
          ? "webp"
          : "jpg";
    const relativeDir = path.join("household-photos", input.householdId);
    const absoluteDir = path.join(process.cwd(), "public", relativeDir);
    await mkdir(absoluteDir, { recursive: true });
    const filename = `${Date.now()}-${safeName.replace(/\.(jpe?g|png|webp)$/i, "")}.${extension}`;
    await writeFile(path.join(absoluteDir, filename), input.data);
    const baseUrl = process.env.BETTER_AUTH_URL ?? "http://localhost:3000";
    return `${baseUrl}/${relativeDir}/${filename}`.replace(/\\/g, "/");
  }

  throw new Error("Household photo uploads are not configured.");
}

export async function saveHouseholdPhoto(input: {
  householdId: string;
  url: string;
}) {
  if (!isValidHouseholdPhotoUrl(input.url, input.householdId)) {
    throw new Error("That household photo URL is not valid.");
  }

  if (isManagedHouseholdPhoto(input.url, input.householdId)) {
    const blob = await head(input.url);
    if (
      !blob.contentType ||
      !PROFILE_PHOTO_TYPES.includes(blob.contentType as HouseholdPhotoType) ||
      blob.size > PROFILE_PHOTO_MAX_BYTES
    ) {
      throw new Error("The uploaded file is not a supported household photo.");
    }
  }

  const existing = await db
    .select({ photo: households.photo })
    .from(households)
    .where(eq(households.id, input.householdId))
    .limit(1);
  if (!existing[0]) throw new Error("Household not found.");

  await db
    .update(households)
    .set({ photo: input.url, updatedAt: new Date() })
    .where(eq(households.id, input.householdId));

  const previous = existing[0].photo;
  if (previous && previous !== input.url) {
    await deleteStoredHouseholdPhoto(previous, input.householdId);
  }
}

export async function removeHouseholdPhoto(householdId: string) {
  const existing = await db
    .select({ photo: households.photo })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);
  if (!existing[0]) throw new Error("Household not found.");

  await db
    .update(households)
    .set({ photo: null, updatedAt: new Date() })
    .where(eq(households.id, householdId));

  if (existing[0].photo) {
    await deleteStoredHouseholdPhoto(existing[0].photo, householdId);
  }
}

async function deleteStoredHouseholdPhoto(url: string, householdId: string) {
  if (isManagedHouseholdPhoto(url, householdId)) {
    await del(url).catch(() => undefined);
    return;
  }
  if (isLocalDevHouseholdPhoto(url, householdId)) {
    await deleteLocalDevHouseholdPhoto(url).catch(() => undefined);
  }
}

async function deleteLocalDevHouseholdPhoto(url: string) {
  const parsed = new URL(url);
  const relativePath = parsed.pathname.replace(/^\//, "");
  await unlink(path.join(process.cwd(), "public", relativePath));
}
