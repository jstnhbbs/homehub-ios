import { asc, eq } from "drizzle-orm";
import { CalendarDays, Copy, Plus, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { addProfile } from "@/app/actions";
import { SignOutButton } from "@/components/sign-out-button";
import { db } from "@/db/client";
import { profiles } from "@/db/schema";
import { requireHousehold } from "@/lib/household";

const colors = ["#d87861", "#6689a3", "#4f7c6d", "#b07aa1", "#d19b45"];

export default async function SettingsPage() {
  const household = await requireHousehold();
  const familyProfiles = await db
    .select()
    .from(profiles)
    .where(eq(profiles.householdId, household.id))
    .orderBy(asc(profiles.sortOrder));

  return (
    <div className="mx-auto max-w-5xl pb-10">
      <div className="flex items-end justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Make it yours
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold">Settings</h1>
        </div>
        <SignOutButton />
      </div>
      <div className="mt-6 grid grid-cols-2 gap-5">
        <section className="hub-card p-6">
          <h2 className="font-display text-2xl font-semibold">Family profiles</h2>
          <div className="mt-5 flex flex-wrap gap-4">
            {familyProfiles.map((profile) => (
              <div
                key={profile.id}
                className="flex items-center gap-3 rounded-2xl border border-[var(--line)] bg-white/60 p-3 pr-5"
              >
                <span
                  className="flex h-10 w-10 items-center justify-center rounded-full font-bold text-white"
                  style={{ background: profile.color }}
                >
                  {profile.name[0]}
                </span>
                <span className="font-bold">{profile.name}</span>
              </div>
            ))}
          </div>
          <form action={addProfile} className="mt-6 flex items-end gap-2">
            <label className="min-w-0 flex-1">
              <span className="mb-1 block text-xs font-bold">Add a child</span>
              <input name="name" className="hub-input" placeholder="Name" required />
            </label>
            <select name="color" className="hub-input !w-24" aria-label="Profile color">
              {colors.map((color) => (
                <option key={color} value={color}>
                  {color}
                </option>
              ))}
            </select>
            <button className="hub-button !h-12 !w-12 !p-0" aria-label="Add profile">
              <Plus size={20} />
            </button>
          </form>
        </section>

        <section className="hub-card p-6">
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

        <section className="hub-card p-6">
          <Copy className="text-[var(--blue)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Invite another parent
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Share this code. They can enter it after creating their parent account.
          </p>
          <div className="mt-5 rounded-2xl bg-[var(--blue-soft)] p-4 text-center font-mono text-2xl font-extrabold tracking-[0.2em]">
            {household.inviteCode}
          </div>
        </section>

        <section className="hub-card p-6">
          <ShieldCheck className="text-[var(--sage)]" size={28} />
          <h2 className="font-display mt-4 text-2xl font-semibold">
            Household privacy
          </h2>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Parents manage the hub. Child profiles never need accounts, and Apple
            credentials stay encrypted on the server.
          </p>
          <div className="mt-5 rounded-2xl border border-[var(--line)] p-4 text-sm">
            <span className="font-bold">Timezone</span>
            <span className="float-right text-[var(--muted)]">
              {household.timezone}
            </span>
          </div>
        </section>
      </div>
    </div>
  );
}
