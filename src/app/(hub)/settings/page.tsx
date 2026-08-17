import { asc, eq } from "drizzle-orm";
import {
  CalendarDays,
  Copy,
  Bell,
  Moon,
  Pencil,
  Plus,
  RotateCcw,
  ShieldCheck,
  Sun,
  Users,
} from "lucide-react";
import Link from "next/link";
import { addProfile, removeGuestMember } from "@/app/actions";
import { ProfileColorPicker } from "@/components/profile-color-picker";
import { ThemeSetting } from "@/components/theme-setting";
import { HubModulesSetting } from "@/components/hub-modules-setting";
import {
  hasProfilePhoto,
  ProfileAvatar,
} from "@/components/profile-avatar";
import { ProfilePhotoUpload } from "@/components/profile-photo-upload";
import { SignOutButton } from "@/components/sign-out-button";
import { db } from "@/db/client";
import { householdMembers, profiles, users } from "@/db/schema";
import { roleLabel } from "@/lib/household-roles";
import { requireHousehold, requireUser } from "@/lib/household";
import { getUserHubModules } from "@/lib/hub-modules-store";

export default async function SettingsPage() {
  const household = await requireHousehold();
  const user = await requireUser();
  const hubModules = await getUserHubModules(user.id);
  const [familyProfiles, members] = await Promise.all([
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
    db
      .select({
        userId: householdMembers.userId,
        role: householdMembers.role,
        joinedAt: householdMembers.joinedAt,
        name: users.name,
        email: users.email,
      })
      .from(householdMembers)
      .innerJoin(users, eq(householdMembers.userId, users.id))
      .where(eq(householdMembers.householdId, household.id))
      .orderBy(asc(householdMembers.joinedAt)),
  ]);
  const adultProfiles = familyProfiles.filter(
    (profile) => profile.profileType === "adult",
  );
  const childProfiles = familyProfiles.filter(
    (profile) => profile.profileType === "child",
  );

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
          <ProfileList title="Adults" profiles={adultProfiles} />
          <ProfileList title="Children" profiles={childProfiles} />
          <form
            action={addProfile}
            className="mt-6 grid gap-3"
          >
            <label className="min-w-0">
              <span className="mb-1 block text-xs font-bold">
                Add a family member
              </span>
              <input name="name" className="hub-input" placeholder="Name" required />
            </label>
            <fieldset>
              <legend className="mb-2 text-xs font-bold">Profile type</legend>
              <div className="flex gap-2">
                {(["adult", "child"] as const).map((profileType) => (
                  <label key={profileType} className="cursor-pointer">
                    <input
                      type="radio"
                      name="profileType"
                      value={profileType}
                      defaultChecked={profileType === "child"}
                      className="peer sr-only"
                    />
                    <span className="block rounded-xl border border-[var(--line)] px-4 py-2 text-sm font-bold capitalize peer-checked:border-[var(--sage)] peer-checked:bg-[var(--sage-soft)]">
                      {profileType}
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
            <ProfileColorPicker />
            <button className="hub-button w-fit px-5">
              <Plus size={18} /> Add family member
            </button>
          </form>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Moon className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Appearance
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Switch between the light and dark theme. Your choice is remembered
            on this device.
          </p>
          <ThemeSetting />
        </section>

        <HubModulesSetting initialModules={hubModules} />

        <section className="hub-card p-6 max-md:p-4">
          <CalendarDays className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Calendars
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Connect Apple or Google calendars and choose which ones appear on
            the hub.
          </p>
          <Link href="/settings/calendar" className="hub-button mt-6">
            Calendar settings
          </Link>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Bell className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Notifications
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Tune reminder categories and quiet hours for this parent account.
          </p>
          <Link href="/settings/notifications" className="hub-button mt-6">
            Reminder settings
          </Link>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Sun className="text-[var(--sun)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Weather
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Set the location used by the dashboard forecast card.
          </p>
          <Link href="/settings/weather" className="hub-button mt-6">
            Weather settings
          </Link>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <RotateCcw className="text-[var(--blue)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Recycle bin
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Restore deleted shopping items, notes, and birthday records.
          </p>
          <Link href="/settings/recycle-bin" className="hub-button mt-6">
            Open recycle bin
          </Link>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Copy className="text-[var(--blue)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Invite another parent
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Share this code. They can enter it after creating their account.
          </p>
          <div className="mt-5 overflow-hidden rounded-2xl bg-[var(--blue-soft)] p-4 text-center font-mono text-2xl font-extrabold tracking-[0.2em] max-sm:text-xl max-sm:tracking-[0.12em]">
            {household.inviteCode}
          </div>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <Users className="text-[var(--sun)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Invite a guest
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            For grandparents, nannies, and other helpers. Guests can view the
            hub and check off routines and chores.
          </p>
          <div className="mt-5 overflow-hidden rounded-2xl bg-[var(--sun-soft)] p-4 text-center font-mono text-2xl font-extrabold tracking-[0.2em] max-sm:text-xl max-sm:tracking-[0.12em]">
            {household.guestInviteCode}
          </div>
        </section>

        <section className="hub-card col-span-2 p-6 max-md:col-span-1 max-md:p-4">
          <h2 className="font-display text-2xl font-semibold">Household members</h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Parents manage the hub. Guests can be removed at any time.
          </p>
          <div className="mt-5 space-y-3">
            {members.map((member) => (
              <div
                key={member.userId}
                className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4"
              >
                <div className="min-w-0">
                  <p className="truncate font-bold">{member.name}</p>
                  <p className="truncate text-sm text-[var(--muted)]">
                    {member.email}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="rounded-full bg-[var(--sage-soft)] px-3 py-1 text-xs font-bold text-[var(--sage)]">
                    {roleLabel(member.role)}
                  </span>
                  {member.role === "guest" && (
                    <form action={removeGuestMember}>
                      <input type="hidden" name="userId" value={member.userId} />
                      <button className="text-sm font-bold text-[var(--coral)]">
                        Remove
                      </button>
                    </form>
                  )}
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="hub-card p-6 max-md:p-4">
          <ShieldCheck className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Household privacy
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Parents manage the hub. Child profiles never need accounts, and
            calendar credentials stay encrypted on the server.
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

function ProfileList({
  title,
  profiles: profileList,
}: {
  title: string;
  profiles: (typeof profiles.$inferSelect)[];
}) {
  return (
    <div className="mt-5">
      <h3 className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
        {title}
      </h3>
      <div className="mt-2 flex flex-wrap gap-3">
        {profileList.map((profile) => (
          <div
            key={profile.id}
            className="flex min-w-[240px] flex-1 items-center gap-3 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-3"
          >
            <ProfileAvatar
              name={profile.name}
              avatar={profile.avatar}
              color={profile.color}
              size={48}
            />
            <div className="min-w-0 flex-1">
              <p className="truncate font-bold">{profile.name}</p>
              {profile.birthday && (
                <p className="mt-0.5 text-xs text-[var(--muted)]">
                  Birthday:{" "}
                  {new Intl.DateTimeFormat("en-US", {
                    month: "long",
                    day: "numeric",
                    timeZone: "UTC",
                  }).format(new Date(`${profile.birthday}T12:00:00Z`))}
                </p>
              )}
              <div className="mt-1.5">
                <ProfilePhotoUpload
                  profileId={profile.id}
                  hasPhoto={hasProfilePhoto(profile.avatar)}
                />
              </div>
            </div>
            <Link
              href={`/settings/profiles/${profile.id}`}
              className="rounded-full p-2 text-[var(--muted)] transition hover:bg-[var(--tile-solid)] hover:text-[var(--foreground)]"
              aria-label={`Edit ${profile.name}`}
            >
              <Pencil size={17} />
            </Link>
          </div>
        ))}
        {profileList.length === 0 && (
          <p className="text-sm text-[var(--muted)]">None added yet.</p>
        )}
      </div>
    </div>
  );
}
