import { del, head, put } from "@vercel/blob";
import { mkdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";

export const PROFILE_PHOTO_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
] as const;
export const PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024;

export function hasProfilePhoto(avatar: string) {
  return isManagedProfilePhoto(avatar, "") || isLocalDevProfilePhoto(avatar, "");
}

function isLocalDevProfilePhoto(url: string, profileId: string) {
  if (process.env.NODE_ENV !== "development") return false;
  try {
    const parsed = new URL(url);
    const prefix = profileId
      ? `/profile-photos/${profileId}/`
      : "/profile-photos/";
    return parsed.pathname.startsWith(prefix);
  } catch {
    return false;
  }
}

function isManagedProfilePhoto(url: string, profileId: string) {
  try {
    const parsed = new URL(url);
    const prefix = profileId
      ? `/profiles/${profileId}/`
      : "/profiles/";
    return (
      parsed.protocol === "https:" &&
      parsed.hostname.endsWith(".public.blob.vercel-storage.com") &&
      parsed.pathname.startsWith(prefix)
    );
  } catch {
    return false;
  }
}

function isValidProfilePhotoUrl(url: string, profileId: string) {
  return (
    isManagedProfilePhoto(url, profileId) ||
    isLocalDevProfilePhoto(url, profileId)
  );
}

export async function uploadProfilePhotoFile(input: {
  profileId: string;
  fileName: string;
  contentType: string;
  data: Buffer;
}) {
  if (!PROFILE_PHOTO_TYPES.includes(input.contentType as ProfilePhotoType)) {
    throw new Error("Choose a JPEG, PNG, or WebP image.");
  }
  if (input.data.byteLength > PROFILE_PHOTO_MAX_BYTES) {
    throw new Error("Choose an image smaller than 5 MB.");
  }

  const safeName = input.fileName.replace(/[^a-zA-Z0-9._-]/g, "-");
  const pathname = `profiles/${input.profileId}/${Date.now()}-${safeName}`;

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
    const relativeDir = path.join("profile-photos", input.profileId);
    const absoluteDir = path.join(process.cwd(), "public", relativeDir);
    await mkdir(absoluteDir, { recursive: true });
    const filename = `${Date.now()}-${safeName}.${extension}`;
    await writeFile(path.join(absoluteDir, filename), input.data);
    const baseUrl = process.env.BETTER_AUTH_URL ?? "http://localhost:3000";
    return `${baseUrl}/${relativeDir}/${filename}`.replace(/\\/g, "/");
  }

  throw new Error("Profile photo uploads are not configured.");
}

type ProfilePhotoType = (typeof PROFILE_PHOTO_TYPES)[number];

export async function saveProfilePhotoForHousehold(input: {
  householdId: string;
  profileId: string;
  url: string;
}) {
  if (!isValidProfilePhotoUrl(input.url, input.profileId)) {
    throw new Error("That profile photo URL is not valid.");
  }

  if (isManagedProfilePhoto(input.url, input.profileId)) {
    const blob = await head(input.url);
    if (
      !blob.contentType ||
      !PROFILE_PHOTO_TYPES.includes(
        blob.contentType as ProfilePhotoType,
      ) ||
      blob.size > PROFILE_PHOTO_MAX_BYTES
    ) {
      throw new Error("The uploaded file is not a supported profile photo.");
    }
  }

  const existing = await db
    .select({ avatar: profiles.avatar })
    .from(profiles)
    .where(
      and(
        eq(profiles.id, input.profileId),
        eq(profiles.householdId, input.householdId),
      ),
    )
    .limit(1);
  if (!existing[0]) throw new Error("Family profile not found.");

  await db
    .update(profiles)
    .set({ avatar: input.url })
    .where(
      and(
        eq(profiles.id, input.profileId),
        eq(profiles.householdId, input.householdId),
      ),
    );

  const previous = existing[0].avatar;
  if (
    previous !== input.url &&
    isManagedProfilePhoto(previous, input.profileId)
  ) {
    await del(previous).catch(() => undefined);
  } else if (
    previous !== input.url &&
    isLocalDevProfilePhoto(previous, input.profileId)
  ) {
    await deleteLocalDevProfilePhoto(previous).catch(() => undefined);
  }
}

export async function removeProfilePhotoForHousehold(input: {
  householdId: string;
  profileId: string;
}) {
  const existing = await db
    .select({ avatar: profiles.avatar })
    .from(profiles)
    .where(
      and(
        eq(profiles.id, input.profileId),
        eq(profiles.householdId, input.householdId),
      ),
    )
    .limit(1);
  if (!existing[0]) throw new Error("Family profile not found.");

  await db
    .update(profiles)
    .set({ avatar: "sparkles" })
    .where(
      and(
        eq(profiles.id, input.profileId),
        eq(profiles.householdId, input.householdId),
      ),
    );

  if (isManagedProfilePhoto(existing[0].avatar, input.profileId)) {
    await del(existing[0].avatar).catch(() => undefined);
  } else if (isLocalDevProfilePhoto(existing[0].avatar, input.profileId)) {
    await deleteLocalDevProfilePhoto(existing[0].avatar).catch(() => undefined);
  }
}

async function deleteLocalDevProfilePhoto(url: string) {
  const parsed = new URL(url);
  const relativePath = parsed.pathname.replace(/^\//, "");
  await unlink(path.join(process.cwd(), "public", relativePath));
}
