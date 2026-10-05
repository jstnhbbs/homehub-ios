"use server";

import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { db } from "@/db/client";
import {
  householdMembers,
  households,
  profiles,
} from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import {
  householdRoles,
  isGuest,
} from "@/lib/household-roles";
import { updateHouseholdMemberRole } from "@/lib/household-members";
import {
  assertMayTryInviteCode,
  clientAddress,
  generateInviteCodePair,
  normalizeInviteCode,
} from "@/lib/invite-codes";
import {
  requireParentHousehold,
  requireUser,
} from "@/lib/household";
import { ensureMemberProfiles } from "@/lib/member-profiles";
import { isProfileColor } from "@/lib/profile-colors";
import {
  removeHouseholdPhoto,
  saveHouseholdPhoto,
  uploadHouseholdPhotoFile,
} from "@/lib/household-photo";
import {
  PROFILE_PHOTO_MAX_BYTES,
  PROFILE_PHOTO_TYPES,
  removeProfilePhotoForHousehold,
  saveProfilePhotoForHousehold,
} from "@/lib/profile-photo";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

const shortText = z.string().trim().min(1).max(120);

export async function createHousehold(formData: FormData) {
  const user = await requireUser();
  const input = z
    .object({
      name: shortText,
      childName: z.string().trim().max(60),
      timezone: z.string().trim().min(1).max(80),
    })
    .parse({
      name: text(formData, "name"),
      childName: text(formData, "childName"),
      timezone: text(formData, "timezone") || "America/Chicago",
    });

  const id = randomUUID();
  const { inviteCode, guestInviteCode } = generateInviteCodePair();
  await db.transaction(async (tx) => {
    await tx.insert(households).values({
      id,
      name: input.name,
      timezone: input.timezone,
      inviteCode,
      guestInviteCode,
    });
    await tx.insert(householdMembers).values({
      householdId: id,
      userId: user.id,
      role: "owner",
    });
    if (input.childName) {
      await tx.insert(profiles).values({
        id: randomUUID(),
        householdId: id,
        name: input.childName,
        color: "#d87861",
      });
    }
  });
  redirect("/settings");
}

export async function joinHousehold(formData: FormData) {
  const user = await requireUser();
  await assertMayTryInviteCode(user.id, clientAddress(await headers()));
  const inviteCode = normalizeInviteCode(text(formData, "inviteCode"));
  const household = await db
    .select({ id: households.id })
    .from(households)
    .where(eq(households.inviteCode, inviteCode))
    .limit(1);
  if (!household[0]) throw new Error("That invite code was not found.");
  await db
    .insert(householdMembers)
    .values({
      householdId: household[0].id,
      userId: user.id,
      role: "parent",
    })
    .onConflictDoNothing();
  await ensureMemberProfiles(household[0].id);
  redirect("/settings");
}

export async function joinHouseholdAsGuest(formData: FormData) {
  const user = await requireUser();
  await assertMayTryInviteCode(user.id, clientAddress(await headers()));
  const inviteCode = normalizeInviteCode(text(formData, "guestInviteCode"));
  const household = await db
    .select({ id: households.id })
    .from(households)
    .where(eq(households.guestInviteCode, inviteCode))
    .limit(1);
  if (!household[0]) throw new Error("That guest invite code was not found.");
  await db
    .insert(householdMembers)
    .values({
      householdId: household[0].id,
      userId: user.id,
      role: "guest",
    })
    .onConflictDoNothing();
  await ensureMemberProfiles(household[0].id);
  redirect("/settings");
}

export async function removeGuestMember(formData: FormData) {
  const household = await requireParentHousehold();
  const userId = z.string().parse(formData.get("userId"));
  const member = await db
    .select({ role: householdMembers.role })
    .from(householdMembers)
    .where(
      and(
        eq(householdMembers.householdId, household.id),
        eq(householdMembers.userId, userId),
      ),
    )
    .limit(1);
  if (!member[0] || !isGuest(member[0].role)) {
    throw new Error("Only guest members can be removed here.");
  }
  await db
    .delete(householdMembers)
    .where(
      and(
        eq(householdMembers.householdId, household.id),
        eq(householdMembers.userId, userId),
      ),
    );
  revalidatePath("/", "layout");
}

export async function updateMemberRole(formData: FormData) {
  const user = await requireUser();
  const household = await requireParentHousehold();
  const userId = z.string().parse(formData.get("userId"));
  const role = z.enum(householdRoles).parse(formData.get("role"));
  await updateHouseholdMemberRole({
    householdId: household.id,
    actorUserId: user.id,
    actorRole: household.role,
    targetUserId: userId,
    nextRole: role,
  });
  revalidatePath("/", "layout");
}

export async function addProfile(formData: FormData) {
  const household = await requireParentHousehold();
  const name = shortText.parse(text(formData, "name"));
  const color = z
    .string()
    .refine(isProfileColor)
    .parse(text(formData, "color") || "#6689a3");
  const profileType = z
    .enum(["adult", "child"])
    .parse(text(formData, "profileType") || "child");
  await db.insert(profiles).values({
    id: randomUUID(),
    householdId: household.id,
    name,
    color,
    profileType,
  });
  revalidatePath("/", "layout");
}

export async function updateProfile(profileId: string, formData: FormData) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(profileId);
  const birthdayValue = text(formData, "birthday");
  const input = z
    .object({
      name: shortText,
      color: z.string().refine(isProfileColor, "Choose a valid profile color."),
      birthday: z.iso.date().nullable(),
      profileType: z.enum(["adult", "child"]),
    })
    .parse({
      name: text(formData, "name"),
      color: text(formData, "color"),
      birthday: birthdayValue || null,
      profileType: text(formData, "profileType"),
    });

  if (
    input.birthday &&
    input.birthday > localDateIn(household.timezone)
  ) {
    throw new Error("Birthday cannot be in the future.");
  }

  const existingProfile = await db
    .select({ userId: profiles.userId })
    .from(profiles)
    .where(
      and(
        eq(profiles.id, id),
        eq(profiles.householdId, household.id),
      ),
    )
    .limit(1);
  if (!existingProfile[0]) throw new Error("Profile not found.");

  await db
    .update(profiles)
    .set({
      name: input.name,
      color: input.color,
      birthday: input.birthday,
      profileType: existingProfile[0].userId ? "adult" : input.profileType,
      updatedAt: new Date(),
    })
    .where(
      and(
        eq(profiles.id, id),
        eq(profiles.householdId, household.id),
      ),
    );

  revalidatePath("/", "layout");
  redirect("/settings");
}

export async function setProfilePhoto(profileId: string, url: string) {
  const household = await requireParentHousehold();
  await saveProfilePhotoForHousehold({
    householdId: household.id,
    profileId: z.string().uuid().parse(profileId),
    url: z.string().url().parse(url),
  });
  revalidatePath("/", "layout");
}

export async function removeProfilePhoto(profileId: string) {
  const household = await requireParentHousehold();
  await removeProfilePhotoForHousehold({
    householdId: household.id,
    profileId: z.string().uuid().parse(profileId),
  });
  revalidatePath("/", "layout");
}

export async function setHouseholdPhoto(formData: FormData) {
  const household = await requireParentHousehold();
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

  const url = await uploadHouseholdPhotoFile({
    householdId: household.id,
    fileName: file.name || "photo.jpg",
    contentType: file.type,
    data: Buffer.from(await file.arrayBuffer()),
  });
  await saveHouseholdPhoto({
    householdId: household.id,
    url,
  });
  revalidatePath("/", "layout");
}

export async function deleteHouseholdPhoto() {
  const household = await requireParentHousehold();
  await removeHouseholdPhoto(household.id);
  revalidatePath("/", "layout");
}
