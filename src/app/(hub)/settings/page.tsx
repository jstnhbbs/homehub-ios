import { asc, eq } from "drizzle-orm";
import { Copy, Plus, ShieldCheck, Users } from "lucide-react";
import { addProfile, removeGuestMember } from "@/app/actions";
import { HouseholdMark } from "@/components/household-mark";
import { HouseholdPhotoUpload } from "@/components/household-photo-upload";
import { MemberRoleSelect } from "@/components/member-role-select";
import { ProfileAvatar } from "@/components/profile-avatar";
import { ProfileColorPicker } from "@/components/profile-color-picker";
import { SignOutButton } from "@/components/sign-out-button";
import { VerifyEmailNotice } from "@/components/verify-email-notice";
import { db } from "@/db/client";
import { householdMembers, profiles, users } from "@/db/schema";
import { requireHousehold, getSession } from "@/lib/household";
import { hasHouseholdPhoto } from "@/lib/household-photo-url";
import {
  assignableRoles,
  canManageHousehold,
  evaluateMemberRoleChange,
  roleLabel,
} from "@/lib/household-roles";

export default async function SettingsPage() {
  const household = await requireHousehold();
  const session = await getSession();
  const actorUserId = session?.user.id ?? "";
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
  const ownerCount = members.filter((item) => item.role === "owner").length;

  return (
    <div className="mx-auto max-w-5xl pb-10">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Web shell
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Household settings
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
            The actively maintained Beacon experience is the iOS app. This web
            shell stays focused on account setup, household membership, and
            backend support.
          </p>
        </div>
        <SignOutButton />
      </div>

      {session && !session.user.emailVerified ? (
        <VerifyEmailNotice email={session.user.email} />
      ) : null}

      <div className="mt-6 grid grid-cols-2 gap-5 max-md:mt-4 max-md:grid-cols-1 max-md:gap-3">
        <section className="hub-card p-6 max-md:p-4">
          <h2 className="font-display text-2xl font-semibold">
            Family profiles
          </h2>
          <div className="mt-4 grid gap-3">
            {familyProfiles.map((profile) => (
              <div
                key={profile.id}
                className="flex items-center gap-3 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-3"
              >
                <ProfileAvatar
                  name={profile.name}
                  avatar={profile.avatar}
                  color={profile.color}
                  size={44}
                />
                <div className="min-w-0">
                  <p className="truncate font-bold">{profile.name}</p>
                  <p className="text-xs font-semibold capitalize text-[var(--muted)]">
                    {profile.profileType}
                  </p>
                </div>
              </div>
            ))}
          </div>

          <form action={addProfile} className="mt-6 grid gap-3">
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
          <Copy className="text-[var(--blue)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Parent invite
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Share this code with another parent after they create an account.
          </p>
          <InviteCode code={household.inviteCode} tone="blue" />

          <Users className="mt-8 text-[var(--sun)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Guest invite
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            For grandparents, nannies, and other helpers.
          </p>
          <InviteCode code={household.guestInviteCode} tone="sun" />
        </section>

        <section className="hub-card col-span-2 p-6 max-md:col-span-1 max-md:p-4">
          <h2 className="font-display text-2xl font-semibold">
            Household members
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Owners and parents can change another member&apos;s role.
          </p>
          <div className="mt-5 space-y-3">
            {members.map((member) => {
              const roleOptions = assignableRoles(household.role).filter(
                (role) =>
                  evaluateMemberRoleChange({
                    actorRole: household.role,
                    actorUserId,
                    targetUserId: member.userId,
                    targetRole: member.role,
                    nextRole: role,
                    ownerCount,
                  }).ok,
              );
              const canEditRole = roleOptions.length > 1;

              return (
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
                    {canEditRole ? (
                      <MemberRoleSelect
                        userId={member.userId}
                        role={member.role}
                        options={roleOptions}
                      />
                    ) : (
                      <span className="rounded-full bg-[var(--sage-soft)] px-3 py-1 text-xs font-bold text-[var(--sage)]">
                        {roleLabel(member.role)}
                      </span>
                    )}
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
              );
            })}
          </div>
        </section>

        <section className="hub-card col-span-2 p-6 max-md:col-span-1 max-md:p-4">
          <ShieldCheck className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Household support
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Family data is stored on the Beacon backend for the iOS app.
            Calendar access is native to each device and is not configured on
            the web.
          </p>
          <div className="mt-5 flex items-center justify-between gap-3 rounded-2xl border border-[var(--line)] p-4 text-sm">
            <span className="font-bold">Timezone</span>
            <span className="truncate text-[var(--muted)]">
              {household.timezone}
            </span>
          </div>
          <div className="mt-3 flex items-center gap-4 rounded-2xl border border-[var(--line)] p-4">
            <HouseholdMark
              name={household.name}
              photo={household.photo}
              size={56}
            />
            <div className="min-w-0">
              <p className="font-bold">Family photo</p>
              <p className="mb-2 text-xs text-[var(--muted)]">
                Optional. Replaces the family-name letter in the iOS sidebar.
              </p>
              {canManageHousehold(household.role) ? (
                <HouseholdPhotoUpload hasPhoto={hasHouseholdPhoto(household.photo)} />
              ) : (
                <p className="text-xs text-[var(--muted)]">
                  Ask a parent to add or change this photo.
                </p>
              )}
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function InviteCode({ code, tone }: { code: string; tone: "blue" | "sun" }) {
  return (
    <div
      className={`mt-5 overflow-hidden rounded-2xl p-4 text-center font-mono text-2xl font-extrabold tracking-[0.2em] max-sm:text-xl max-sm:tracking-[0.12em] ${
        tone === "blue" ? "bg-[var(--blue-soft)]" : "bg-[var(--sun-soft)]"
      }`}
    >
      {code}
    </div>
  );
}
