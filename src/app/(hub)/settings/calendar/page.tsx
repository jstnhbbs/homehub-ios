import { eq } from "drizzle-orm";
import {
  Check,
  CheckCircle2,
  ExternalLink,
  LockKeyhole,
} from "lucide-react";
import Link from "next/link";
import { CalendarSync } from "@/components/calendar-sync";
import { db } from "@/db/client";
import { calendarConnections, calendars } from "@/db/schema";
import { requireHousehold } from "@/lib/household";
import {
  connectCalendar,
  disconnectCalendar,
  updateCalendarSelection,
} from "./actions";

export default async function CalendarSettingsPage() {
  const household = await requireHousehold();
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(eq(calendarConnections.householdId, household.id))
    .limit(1);
  const current = connection[0];
  const calendarList = current
    ? await db
        .select()
        .from(calendars)
        .where(eq(calendars.connectionId, current.id))
    : [];

  return (
    <div className="mx-auto max-w-4xl pb-10">
      <Link href="/settings" className="text-sm font-bold text-[var(--sage)]">
        ← Settings
      </Link>
      <div className="mt-3 flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div className="min-w-0">
          <h1 className="font-display text-4xl font-semibold max-md:text-3xl">
            Apple Calendar
          </h1>
          <p className="mt-2 text-[var(--muted)]">
            Private, two-way calendar sync through iCloud CalDAV.
          </p>
        </div>
        <CalendarSync
          connected={Boolean(current)}
          lastSyncedAt={current?.lastSyncedAt?.toISOString()}
        />
      </div>

      {current ? (
        <div className="mt-7 space-y-5">
          <section className="hub-card p-6">
            <div className="flex items-center gap-3">
              <CheckCircle2 className="text-[var(--sage)]" />
              <div>
                <h2 className="break-all font-bold">
                  Connected as {current.appleId}
                </h2>
                <p className="text-sm text-[var(--muted)]">
                  {calendarList.filter((calendar) => calendar.enabled).length} of{" "}
                  {calendarList.length} calendars displayed
                </p>
              </div>
            </div>
            <form action={updateCalendarSelection} className="mt-5">
              <fieldset>
                <legend className="text-sm font-bold">
                  Calendars shown on the hub
                </legend>
                <p className="mt-1 text-xs text-[var(--muted)]">
                  Unselected calendars stay private in iCloud and will not be
                  synced or displayed here.
                </p>
                <div className="mt-4 grid gap-3 sm:grid-cols-2">
                  {calendarList.map((calendar) => (
                    <label
                      key={calendar.id}
                      className="group flex min-h-16 cursor-pointer items-center gap-3 rounded-2xl border border-[var(--line)] p-4 transition has-[:checked]:border-[var(--sage)] has-[:checked]:bg-[var(--sage-soft)]/45"
                    >
                      <input
                        type="checkbox"
                        name="calendarId"
                        value={calendar.id}
                        defaultChecked={calendar.enabled}
                        className="peer sr-only"
                      />
                      <span
                        className="h-4 w-4 shrink-0 rounded-full"
                        style={{ background: calendar.color }}
                      />
                      <span className="min-w-0 flex-1 truncate font-bold">
                        {calendar.displayName}
                      </span>
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border-2 border-[var(--line)] text-transparent transition peer-checked:border-[var(--sage)] peer-checked:bg-[var(--sage)] peer-checked:text-white">
                        <Check size={16} strokeWidth={3} />
                      </span>
                    </label>
                  ))}
                </div>
              </fieldset>
              <button className="hub-button mt-5">Save calendar selection</button>
            </form>
            {current.status === "error" && (
              <p className="mt-5 rounded-xl bg-[var(--coral-soft)] p-4 text-sm">
                {current.errorMessage}
              </p>
            )}
            <form action={disconnectCalendar} className="mt-6">
              <button className="hub-button danger">Disconnect iCloud</button>
            </form>
          </section>
        </div>
      ) : (
        <div className="mt-7 grid gap-6 md:grid-cols-[0.9fr_1.1fr]">
          <section className="hub-card p-6">
            <LockKeyhole className="text-[var(--sage)]" size={30} />
            <h2 className="font-display mt-4 text-2xl font-semibold">
              Before you connect
            </h2>
            <ol className="mt-4 space-y-4 text-sm leading-6 text-[var(--muted)]">
              <li>1. Open your Apple Account security settings.</li>
              <li>2. Choose App-Specific Passwords and create one for Home Hub.</li>
              <li>3. Paste that password here—not your Apple Account password.</li>
            </ol>
            <a
              href="https://account.apple.com/account/manage"
              target="_blank"
              rel="noreferrer"
              className="mt-5 inline-flex items-center gap-2 font-bold text-[var(--sage)]"
            >
              Open Apple Account <ExternalLink size={16} />
            </a>
          </section>
          <section className="hub-card p-6">
            <h2 className="font-display text-2xl font-semibold">
              Connect iCloud
            </h2>
            <form action={connectCalendar} className="mt-5 space-y-4">
              <label className="block">
                <span className="mb-1.5 block text-sm font-bold">
                  Apple Account email
                </span>
                <input
                  name="username"
                  type="email"
                  className="hub-input"
                  required
                />
              </label>
              <label className="block">
                <span className="mb-1.5 block text-sm font-bold">
                  App-specific password
                </span>
                <input
                  name="password"
                  type="password"
                  className="hub-input"
                  minLength={16}
                  required
                />
              </label>
              <p className="text-xs leading-5 text-[var(--muted)]">
                The password is encrypted before storage and used only by the
                server when communicating with iCloud.
              </p>
              <button className="hub-button w-full">Connect calendars</button>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}
