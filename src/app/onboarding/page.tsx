import { createHousehold, joinHousehold, joinHouseholdAsGuest } from "@/app/actions";
import { getCurrentHousehold, requireUser } from "@/lib/household";
import { Home, UserPlus, Users } from "lucide-react";
import { redirect } from "next/navigation";

export default async function OnboardingPage() {
  await requireUser();
  if (await getCurrentHousehold()) redirect("/dashboard");

  return (
    <main className="min-h-dvh p-6 md:p-10">
      <div className="mx-auto max-w-5xl">
        <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
          One quick setup
        </p>
        <h1 className="font-display mt-2 text-5xl font-semibold">
          Let’s make this hub yours.
        </h1>
        <p className="mt-3 max-w-xl text-lg text-[var(--muted)]">
          Start a household, join as a parent, or join as a guest with a view-only
          invite code.
        </p>
        <div className="mt-10 grid gap-6 lg:grid-cols-3">
          <section className="hub-card p-7">
            <Home className="mb-5 text-[var(--sage)]" size={32} />
            <h2 className="font-display text-3xl font-semibold">
              Create a household
            </h2>
            <form action={createHousehold} className="mt-6 space-y-4">
              <input
                className="hub-input"
                name="name"
                placeholder="The Hobbs family"
                required
              />
              <input
                className="hub-input"
                name="childName"
                placeholder="First child’s name (optional)"
              />
              <input
                className="hub-input"
                name="timezone"
                defaultValue="America/Chicago"
                required
              />
              <button className="hub-button w-full">Create our hub</button>
            </form>
          </section>
          <section className="hub-card p-7">
            <Users className="mb-5 text-[var(--blue)]" size={32} />
            <h2 className="font-display text-3xl font-semibold">
              Join as a parent
            </h2>
            <p className="mt-2 text-[var(--muted)]">
              Enter the parent invite code from household settings.
            </p>
            <form action={joinHousehold} className="mt-6 space-y-4">
              <input
                className="hub-input uppercase tracking-[0.2em]"
                name="inviteCode"
                placeholder="PARENT12"
                required
              />
              <button className="hub-button secondary w-full">
                Join as parent
              </button>
            </form>
          </section>
          <section className="hub-card p-7">
            <UserPlus className="mb-5 text-[var(--sun)]" size={32} />
            <h2 className="font-display text-3xl font-semibold">
              Join as a guest
            </h2>
            <p className="mt-2 text-[var(--muted)]">
              For grandparents, nannies, and other helpers. View the hub and
              check off routines and chores.
            </p>
            <form action={joinHouseholdAsGuest} className="mt-6 space-y-4">
              <input
                className="hub-input uppercase tracking-[0.2em]"
                name="guestInviteCode"
                placeholder="GUEST12"
                required
              />
              <button className="hub-button secondary w-full">
                Join as guest
              </button>
            </form>
          </section>
        </div>
      </div>
    </main>
  );
}
