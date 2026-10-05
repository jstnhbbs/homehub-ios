import { del, put } from "@vercel/blob";
import { mkdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { PROFILE_PHOTO_MAX_BYTES } from "@/lib/profile-photo";

export const RECIPE_IMAGE_MAX_BYTES = PROFILE_PHOTO_MAX_BYTES;

type ImageType = "image/jpeg" | "image/png" | "image/webp";

/**
 * What the bytes actually are, from their first few bytes. The type a client claims is not trusted:
 * a file that isn't really a JPEG, PNG or WebP is refused whatever it says it is.
 */
export function sniffImageType(data: Uint8Array): ImageType | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) return "image/jpeg";
  if (
    data.length >= 8 &&
    data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4e && data[3] === 0x47 &&
    data[4] === 0x0d && data[5] === 0x0a && data[6] === 0x1a && data[7] === 0x0a
  ) {
    return "image/png";
  }
  if (
    data.length >= 12 &&
    String.fromCharCode(...data.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...data.slice(8, 12)) === "WEBP"
  ) {
    return "image/webp";
  }
  return null;
}

const EXTENSIONS: Record<ImageType, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

/** A recipe photo this app stored for this household (so it is ours to replace or delete). */
export function isManagedRecipeImage(url: string, householdId: string) {
  try {
    const parsed = new URL(url);
    return (
      parsed.protocol === "https:" &&
      parsed.hostname.endsWith(".public.blob.vercel-storage.com") &&
      parsed.pathname.startsWith(`/recipes/${householdId}/`)
    );
  } catch {
    return false;
  }
}

function isLocalDevImage(url: string, householdId: string) {
  if (process.env.NODE_ENV !== "development") return false;
  try {
    return new URL(url).pathname.startsWith(`/recipe-images/${householdId}/`);
  } catch {
    return false;
  }
}

/** Stores a recipe photo and returns its URL. */
export async function storeRecipeImage(input: {
  householdId: string;
  recipeId: string;
  data: Buffer;
}) {
  if (input.data.byteLength > RECIPE_IMAGE_MAX_BYTES) {
    throw new Error("Choose an image smaller than 5 MB.");
  }
  const contentType = sniffImageType(input.data);
  if (!contentType) throw new Error("Choose a JPEG, PNG, or WebP image.");
  const extension = EXTENSIONS[contentType];
  const pathname = `recipes/${input.householdId}/${input.recipeId}/photo.${extension}`;

  if (process.env.BLOB_READ_WRITE_TOKEN) {
    const blob = await put(pathname, input.data, {
      access: "public",
      contentType,
      addRandomSuffix: true,
      cacheControlMaxAge: 60 * 60 * 24 * 30,
    });
    return blob.url;
  }

  if (process.env.NODE_ENV === "development") {
    const relativeDir = path.join("recipe-images", input.householdId, input.recipeId);
    const absoluteDir = path.join(process.cwd(), "public", relativeDir);
    await mkdir(absoluteDir, { recursive: true });
    const filename = `${Date.now()}.${extension}`;
    await writeFile(path.join(absoluteDir, filename), input.data);
    const baseUrl = process.env.BETTER_AUTH_URL ?? "http://localhost:3000";
    return `${baseUrl}/${relativeDir}/${filename}`.replace(/\\/g, "/");
  }

  throw new Error("Recipe photo uploads are not configured.");
}

/** Removes a stored photo when it is one of ours; a link to somebody else's image is left alone. */
export async function deleteStoredRecipeImage(url: string, householdId: string) {
  if (isManagedRecipeImage(url, householdId)) {
    await del(url).catch(() => undefined);
    return;
  }
  if (isLocalDevImage(url, householdId)) {
    const relativePath = new URL(url).pathname.replace(/^\//, "");
    await unlink(path.join(process.cwd(), "public", relativePath)).catch(() => undefined);
  }
}
