import { handleUpload, type HandleUploadBody } from "@vercel/blob/client";
import { and, eq } from "drizzle-orm";
import { NextResponse } from "next/server";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { getCurrentHousehold, getSession } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import {
  PROFILE_PHOTO_MAX_BYTES,
  PROFILE_PHOTO_TYPES,
  saveProfilePhotoForHousehold,
} from "@/lib/profile-photo";
import { checkRateLimit } from "@/lib/rate-limit";

export const runtime = "nodejs";

const payloadSchema = z.object({
  profileId: z.string().uuid(),
  householdId: z.string().uuid().optional(),
});

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as HandleUploadBody;
    const response = await handleUpload({
      body,
      request,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        const session = await getSession();
        const household = await getCurrentHousehold();
        if (!session || !household) throw new Error("Not authenticated.");
        if (!canManageHousehold(household.role)) {
          throw new Error("You do not have permission to do that.");
        }

        const { profileId } = payloadSchema.parse(
          JSON.parse(clientPayload ?? "{}"),
        );
        const profile = await db
          .select({ id: profiles.id })
          .from(profiles)
          .where(
            and(
              eq(profiles.id, profileId),
              eq(profiles.householdId, household.id),
            ),
          )
          .limit(1);
        if (!profile[0]) throw new Error("Family profile not found.");
        if (!pathname.startsWith(`profiles/${profileId}/`)) {
          throw new Error("Invalid upload path.");
        }

        const allowed = await checkRateLimit(
          "profile-photo-upload",
          session.user.id,
          { limit: 20, windowMs: 15 * 60 * 1000 },
        );
        if (!allowed) throw new Error("Too many upload attempts.");

        return {
          allowedContentTypes: [...PROFILE_PHOTO_TYPES],
          maximumSizeInBytes: PROFILE_PHOTO_MAX_BYTES,
          addRandomSuffix: true,
          cacheControlMaxAge: 60 * 60 * 24 * 30,
          tokenPayload: JSON.stringify({
            profileId,
            householdId: household.id,
          }),
        };
      },
      onUploadCompleted: async ({ blob, tokenPayload }) => {
        const payload = payloadSchema.extend({
          householdId: z.string().uuid(),
        }).parse(JSON.parse(tokenPayload ?? "{}"));
        await saveProfilePhotoForHousehold({
          householdId: payload.householdId,
          profileId: payload.profileId,
          url: blob.url,
        });
      },
    });
    return NextResponse.json(response);
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Profile photo upload failed.",
      },
      { status: 400 },
    );
  }
}
