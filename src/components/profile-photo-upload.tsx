"use client";

import { upload } from "@vercel/blob/client";
import { Camera, LoaderCircle, Trash2 } from "lucide-react";
import { ChangeEvent, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  removeProfilePhoto,
  setProfilePhoto,
} from "@/app/actions";

const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const maxBytes = 5 * 1024 * 1024;

export function ProfilePhotoUpload({
  profileId,
  hasPhoto,
}: {
  profileId: string;
  hasPhoto: boolean;
}) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState("");
  const [removing, startRemoving] = useTransition();

  async function selectPhoto(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError("");
    if (!allowedTypes.has(file.type)) {
      setError("Choose a JPEG, PNG, or WebP image.");
      event.target.value = "";
      return;
    }
    if (file.size > maxBytes) {
      setError("Choose an image smaller than 5 MB.");
      event.target.value = "";
      return;
    }

    setUploading(true);
    setProgress(0);
    try {
      const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
      const blob = await upload(
        `profiles/${profileId}/${Date.now()}-${safeName}`,
        file,
        {
          access: "public",
          handleUploadUrl: "/api/profile-photo/upload",
          clientPayload: JSON.stringify({ profileId }),
          onUploadProgress: ({ percentage }) => setProgress(percentage),
        },
      );
      await setProfilePhoto(profileId, blob.url);
      router.refresh();
    } catch (uploadError) {
      setError(
        uploadError instanceof Error
          ? uploadError.message
          : "The photo could not be uploaded.",
      );
    } finally {
      setUploading(false);
      event.target.value = "";
    }
  }

  return (
    <div className="min-w-0">
      <div className="flex flex-wrap items-center gap-2">
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          className="sr-only"
          onChange={selectPhoto}
          disabled={uploading || removing}
          aria-label="Choose profile photo"
        />
        <button
          type="button"
          className="inline-flex min-h-9 items-center gap-1.5 rounded-full border border-[var(--line)] bg-[var(--tile-solid)] px-3 text-xs font-bold"
          onClick={() => inputRef.current?.click()}
          disabled={uploading || removing}
        >
          {uploading ? (
            <LoaderCircle size={14} className="animate-spin" />
          ) : (
            <Camera size={14} />
          )}
          {uploading ? `${Math.round(progress)}%` : hasPhoto ? "Replace" : "Photo"}
        </button>
        {hasPhoto && (
          <button
            type="button"
            className="inline-flex min-h-9 items-center gap-1 rounded-full px-2 text-xs font-bold text-[var(--coral)]"
            disabled={uploading || removing}
            onClick={() =>
              startRemoving(async () => {
                setError("");
                try {
                  await removeProfilePhoto(profileId);
                  router.refresh();
                } catch (removeError) {
                  setError(
                    removeError instanceof Error
                      ? removeError.message
                      : "The photo could not be removed.",
                  );
                }
              })
            }
          >
            <Trash2 size={13} />
            Remove
          </button>
        )}
      </div>
      {error && (
        <p className="mt-1 max-w-52 text-xs leading-4 text-[var(--coral)]">
          {error}
        </p>
      )}
    </div>
  );
}
