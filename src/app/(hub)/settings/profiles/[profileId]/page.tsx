import { and, eq } from "drizzle-orm";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { updateProfile } from "@/app/actions";
import {
  hasProfilePhoto,
  ProfileAvatar,
} from "@/components/profile-avatar";
import { ProfileColorPicker } from "@/components/profile-color-picker";
import { ProfilePhotoUpload } from "@/components/profile-photo-upload";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";

export default async function EditProfilePage({
  params,
}: {
  params: Promise<{ profileId: string }>;
}) {
  const household = await requireHousehold();
  const { profileId } = await params;
  const profile = await db
    .select()
    .from(profiles)
    .where(
      and(
        eq(profiles.id, profileId),
        eq(profiles.householdId, household.id),
      ),
    )
    .limit(1);

  if (!profile[0]) notFound();
  const familyMember = profile[0];

  return (
    <div className="mx-auto max-w-2xl pb-10">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-sm font-bold text-[var(--muted)]"
      >
        <ArrowLeft size={16} /> Back to settings
      </Link>

      <section className="hub-card mt-5 p-6 max-md:p-4">
        <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
          {familyMember.profileType} profile
        </p>
        <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
          Edit {familyMember.name}
        </h1>

        <div className="mt-6 flex items-center gap-4 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4">
          <ProfileAvatar
            name={familyMember.name}
            avatar={familyMember.avatar}
            color={familyMember.color}
            size={72}
            className="text-2xl"
          />
          <div>
            <p className="font-bold">Profile photo</p>
            <p className="mb-2 text-xs text-[var(--muted)]">
              Upload, replace, or remove this family member’s photo.
            </p>
            <ProfilePhotoUpload
              profileId={familyMember.id}
              hasPhoto={hasProfilePhoto(familyMember.avatar)}
            />
          </div>
        </div>

        <form
          action={updateProfile.bind(null, familyMember.id)}
          className="mt-6 space-y-5"
        >
          <label className="block">
            <span className="mb-1 block text-xs font-bold">Name</span>
            <input
              name="name"
              className="hub-input"
              defaultValue={familyMember.name}
              required
              maxLength={120}
            />
          </label>

          <label className="block">
            <span className="mb-1 block text-xs font-bold">Birthday</span>
            <input
              name="birthday"
              type="date"
              className="hub-input"
              defaultValue={familyMember.birthday ?? ""}
              max={localDateIn(household.timezone)}
            />
            <span className="mt-1 block text-xs text-[var(--muted)]">
              Birthdays appear as annual all-day events in the family calendar.
            </span>
          </label>

          {familyMember.userId ? (
            <>
              <input type="hidden" name="profileType" value="adult" />
              <p className="text-xs text-[var(--muted)]">
                This adult profile is linked to a parent account.
              </p>
            </>
          ) : (
            <fieldset>
              <legend className="mb-2 text-xs font-bold">Profile type</legend>
              <div className="flex gap-2">
                {(["adult", "child"] as const).map((profileType) => (
                  <label key={profileType} className="cursor-pointer">
                    <input
                      type="radio"
                      name="profileType"
                      value={profileType}
                      defaultChecked={
                        profileType === familyMember.profileType
                      }
                      className="peer sr-only"
                    />
                    <span className="block rounded-xl border border-[var(--line)] px-4 py-2 text-sm font-bold capitalize peer-checked:border-[var(--sage)] peer-checked:bg-[var(--sage-soft)]">
                      {profileType}
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
          )}

          <ProfileColorPicker defaultColor={familyMember.color} />

          <div className="flex flex-wrap gap-3">
            <button className="hub-button px-6">Save changes</button>
            <Link
              href="/settings"
              className="inline-flex min-h-12 items-center rounded-2xl px-5 font-bold text-[var(--muted)]"
            >
              Cancel
            </Link>
          </div>
        </form>
      </section>
    </div>
  );
}
