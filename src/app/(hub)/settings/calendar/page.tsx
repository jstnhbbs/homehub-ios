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
import { calendarSyncStatus } from "@/lib/calendar/connections";
import { requireHousehold } from "@/lib/household";
import {
  connectCalendar,
  disconnectCalendar,
  updateCalendarSelection,
  updateCalendarSyncInterval,
} from "./actions";
import {
  CALENDAR_SYNC_INTERVAL_OPTIONS,
} from "@/lib/calendar/sync-interval";

function providerLabel(provider: "icloud" | "google") {
  return provider === "google" ? "Google Calendar" : "Apple Calendar";
}

export default async function CalendarSettingsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const household = await requireHousehold();
  const params = await searchParams;
  const connections = await db
    .select()
    .from(calendarConnections)
    .where(eq(calendarConnections.householdId, household.id));
  const calendarList = connections.length
    ? await db
        .select({
          id: calendars.id,
          displayName: calendars.displayName,
          color: calendars.color,
          enabled: calendars.enabled,
          connectionId: calendars.connectionId,
          provider: calendarConnections.provider,
        })
        .from(calendars)
        .innerJoin(
          calendarConnections,
          eq(calendars.connectionId, calendarConnections.id),
        )
        .where(eq(calendarConnections.householdId, household.id))
    : [];
  const syncStatus = calendarSyncStatus(connections, household.timezone);
  const icloud = connections.find((item) => item.provider === "icloud");
  const google = connections.find((item) => item.provider === "google");
  const errorMessage =
    params.error === "rate-limit"
      ? "Too many connection attempts. Try again later."
      : params.error === "google-not-configured"
        ? "Google Calendar is not configured on this server yet."
        : params.error === "google-auth-denied"
          ? "Google authorization was cancelled."
          : params.error === "google-connect-failed"
            ? "Google Calendar could not be connected. Try again."
            : null;
  const successMessage =
    params.connected === "google" ? "Google Calendar connected." : null;

  return (
    <div className="mx-auto max-w-4xl pb-10">
      <Link href="/settings" className="text-sm font-bold text-[var(--sage)]">
        ← Settings
      </Link>
      <div className="mt-3 flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div className="min-w-0">
          <h1 className="font-display text-4xl font-semibold max-md:text-3xl">
            Calendars
          </h1>
          <p className="mt-2 text-[var(--muted)]">
            Connect Apple or Google calendars for private, two-way sync.
          </p>
        </div>
        <CalendarSync
          connected={syncStatus.connected}
          updatedLabel={syncStatus.updatedLabel}
          lastSyncedAt={syncStatus.lastSyncedAt}
          syncIntervalMinutes={household.calendarSyncIntervalMinutes}
        />
      </div>

      {errorMessage && (
        <p className="mt-5 rounded-xl bg-[var(--coral-soft)] p-4 text-sm">
          {errorMessage}
        </p>
      )}
      {successMessage && (
        <p className="mt-5 rounded-xl bg-[var(--sage-soft)] p-4 text-sm text-[var(--sage)]">
          {successMessage}
        </p>
      )}

      <section className="hub-card mt-7 p-6">
        <h2 className="font-display text-2xl font-semibold">Auto-sync</h2>
        <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
          Choose how often Home Hub checks connected calendars while someone has
          the hub open. Manual sync is always available from the sync button.
        </p>
        <form action={updateCalendarSyncInterval} className="mt-5 flex flex-wrap items-end gap-3">
          <label className="block min-w-56 flex-1">
            <span className="mb-1.5 block text-sm font-bold">Sync frequency</span>
            <select
              name="intervalMinutes"
              defaultValue={household.calendarSyncIntervalMinutes}
              className="hub-input"
              aria-label="Calendar auto-sync frequency"
            >
              {CALENDAR_SYNC_INTERVAL_OPTIONS.map((option) => (
                <option key={option.minutes} value={option.minutes}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
          <button className="hub-button">Save frequency</button>
        </form>
      </section>

      <div className="mt-7 space-y-5">
        <ProviderSection
          provider="icloud"
          connected={icloud}
          calendarList={calendarList.filter(
            (calendar) => calendar.provider === "icloud",
          )}
        />
        <ProviderSection
          provider="google"
          connected={google}
          calendarList={calendarList.filter(
            (calendar) => calendar.provider === "google",
          )}
        />
      </div>
    </div>
  );
}

function ProviderSection({
  provider,
  connected,
  calendarList,
}: {
  provider: "icloud" | "google";
  connected?: (typeof calendarConnections.$inferSelect);
  calendarList: Array<{
    id: string;
    displayName: string;
    color: string;
    enabled: boolean;
  }>;
}) {
  const title = providerLabel(provider);

  if (connected) {
    return (
      <section className="hub-card p-6">
        <div className="flex items-center gap-3">
          <CheckCircle2 className="text-[var(--sage)]" />
          <div>
            <h2 className="break-all font-bold">
              {title} connected as {connected.accountEmail}
            </h2>
            <p className="text-sm text-[var(--muted)]">
              {calendarList.filter((calendar) => calendar.enabled).length} of{" "}
              {calendarList.length} calendars displayed
            </p>
          </div>
        </div>
        {calendarList.length > 0 && (
          <form action={updateCalendarSelection} className="mt-5">
            <fieldset>
              <legend className="text-sm font-bold">
                Calendars shown on the hub
              </legend>
              <p className="mt-1 text-xs text-[var(--muted)]">
                New calendars appear here after sync. Enable them to display and
                sync events. Unselected calendars stay private.
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
        )}
        {connected.status === "error" && (
          <p className="mt-5 rounded-xl bg-[var(--coral-soft)] p-4 text-sm">
            {connected.errorMessage}
          </p>
        )}
        <form action={disconnectCalendar} className="mt-6">
          <input type="hidden" name="provider" value={provider} />
          <button className="hub-button danger">Disconnect {title}</button>
        </form>
      </section>
    );
  }

  if (provider === "google") {
    return (
      <section className="hub-card p-6">
        <h2 className="font-display text-2xl font-semibold">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
          Sign in with Google to sync calendars both ways. Home Hub stores an
          encrypted refresh token and only uses it for calendar access.
        </p>
        <a href="/api/calendar/google/connect" className="hub-button mt-5 inline-flex">
          Connect Google Calendar
        </a>
      </section>
    );
  }

  return (
    <div className="grid gap-6 md:grid-cols-[0.9fr_1.1fr]">
      <section className="hub-card p-6">
        <LockKeyhole className="text-[var(--sage)]" size={30} />
        <h2 className="font-display mt-4 text-2xl font-semibold">
          Before you connect Apple
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
        <h2 className="font-display text-2xl font-semibold">{title}</h2>
        <form action={connectCalendar} className="mt-5 space-y-4">
          <label className="block">
            <span className="mb-1.5 block text-sm font-bold">
              Apple Account email
            </span>
            <input name="username" type="email" className="hub-input" required />
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
          <button className="hub-button w-full">Connect Apple Calendar</button>
        </form>
      </section>
    </div>
  );
}
