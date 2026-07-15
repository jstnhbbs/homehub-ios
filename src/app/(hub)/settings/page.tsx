import { asc, eq } from "drizzle-orm";
import { CalendarDays, Copy, Plus, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { addProfile } from "@/app/actions";
import {
  hasProfilePhoto,
  ProfileAvatar,
} from "@/components/profile-avatar";
import { ProfilePhotoUpload } from "@/components/profile-photo-upload";
import { SignOutButton } from "@/components/sign-out-button";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { requireHousehold } from "@/lib/household";

const colors = [
  { value: "#d87861", label: "Coral" },
  { value: "#6689a3", label: "Blue" },
  { value: "#4f7c6d", label: "Sage" },
  { value: "#b07aa1", label: "Plum" },
  { value: "#d19b45", label: "Gold" },
  { value: "#5f8f8b", label: "Teal" },
  { value: "#8c7ca8", label: "Lavender" },
  { value: "#b86f4d", label: "Terracotta" },
  { value: "#7f8757", label: "Olive" },
];

export default async function SettingsPage() {
  const household = await requireHousehold();
  const familyProfiles = await db
    .select()
    .from(profiles)
    .where(eq(profiles.householdId, household.id))
    .orderBy(asc(profiles.sortOrder));

  return (
    <div className="mx-auto max-w-5xl pb-10">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Make it yours
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Settings
          </h1>
        </div>
        <SignOutButton />
      </div>
      <div className="mt-6 grid grid-cols-2 gap-5 max-md:mt-4 max-md:grid-cols-1 max-md:gap-3">
        <section className="hub-card p-6 max-md:p-4">
          <h2 className="font-display text-2xl font-semibold">Family profiles</h2>
          <div className="mt-5 flex flex-wrap gap-4">
            {familyProfiles.map((profile) => (
              <div
                key={profile.id}
                className="flex min-w-[240px] flex-1 items-center gap-3 rounded-2xl border border-[var(--line)] bg-white/60 p-3"
              >
                <ProfileAvatar
                  name={profile.name}
                  avatar={profile.avatar}
                  color={profile.color}
                  size={48}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-bold">{profile.name}</p>
                  <div className="mt-1.5">
                    <ProfilePhotoUpload
                      profileId={profile.id}
                      hasPhoto={hasProfilePhoto(profile.avatar)}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
          <form
            action={addProfile}
            className="mt-6 grid gap-3"
          >
            <label className="min-w-0">
              <span className="mb-1 block text-xs font-bold">Add a child</span>
              <input name="name" className="hub-input" placeholder="Name" required />
            </label>
            <fieldset>
              <legend className="mb-2 text-xs font-bold">Profile color</legend>
              <div className="flex flex-wrap gap-2.5">
                {colors.map((color, index) => (
                  <label
                    key={color.value}
                    className="cursor-pointer"
                    title={color.label}
                  >
                    <input
                      type="radio"
                      name="color"
                      value={color.value}
                      defaultChecked={index === 0}
                      className="peer sr-only"
                    />
                    <span
                      className="flex h-10 w-10 items-center justify-center rounded-full border-2 border-white ring-1 ring-[var(--line)] transition peer-checked:ring-4 peer-checked:ring-[var(--foreground)]/30"
                      style={{ background: color.value }}
                    >
                      <span className="sr-only">{color.label}</span>
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
            <button className="hub-button w-fit px-5">
              <Plus size={18} /> Add child
            </button>
          </form>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <CalendarDays className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Apple Calendar
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Connect, sync, and choose the iCloud calendars shown around the hub.
          </p>
          <Link href="/settings/calendar" className="hub-button mt-6">
            Calendar settings
          </Link>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Copy className="text-[var(--blue)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Invite another parent
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Share this code. They can enter it after creating their parent account.
          </p>
          <div className="mt-5 overflow-hidden rounded-2xl bg-[var(--blue-soft)] p-4 text-center font-mono text-2xl font-extrabold tracking-[0.2em] max-sm:text-xl max-sm:tracking-[0.12em]">
            {household.inviteCode}
          </div>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <ShieldCheck className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Household privacy
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Parents manage the hub. Child profiles never need accounts, and Apple
            credentials stay encrypted on the server.
          </p>
          <div className="mt-5 flex items-center justify-between gap-3 rounded-2xl border border-[var(--line)] p-4 text-sm">
            <span className="font-bold">Timezone</span>
            <span className="truncate text-[var(--muted)]">
              {household.timezone}
            </span>
          </div>
        </section>
      </div>
    </div>
  );
}
