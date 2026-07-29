"use client";

import { formatInTimeZone } from "date-fns-tz";
import { useEffect, useMemo, useState } from "react";
import {
  createManualNapAction,
  createNightSleepAction,
  deleteNapAction,
  endNapAction,
  startNapAction,
  startNightSleepAction,
  updateNapAction,
} from "@/app/(hub)/sleep/actions";
import {
  defaultManualStartInput,
  toLocalDateTimeInput,
} from "@/lib/naps/datetime";
import {
  formatSleepDuration,
  formatChildTodaySleepSummary,
  formatDashboardSleepSecondary,
  getChildDashboardSleepStatus,
  napDurationMinutes,
  sleepKindLabel,
} from "@/lib/naps/helpers";
import { sleepLogsOnDate } from "@/lib/naps/overlap";
import type { SleepKind } from "@/db/schema";

type ChildProfile = {
  id: string;
  name: string;
  color: string;
};

type SleepItem = {
  id: string;
  profileId: string;
  kind?: SleepKind;
  localDate: string;
  startedAt: string;
  endedAt: string | null;
};

function profileColorStyle(color: string) {
  return { backgroundColor: color };
}

function LiveDuration({
  startedAt,
  endedAt,
}: {
  startedAt: string;
  endedAt: string | null;
}) {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    if (endedAt) return;
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, [endedAt]);

  const minutes = napDurationMinutes(
    new Date(startedAt),
    endedAt ? new Date(endedAt) : null,
    now,
  );

  return <span>{formatSleepDuration(minutes)}</span>;
}

export function ManualNightSleepForm({
  childProfiles,
  timezone,
}: {
  childProfiles: ChildProfile[];
  timezone: string;
}) {
  const defaultProfileId = childProfiles[0]?.id ?? "";
  const [profileId, setProfileId] = useState(defaultProfileId);
  const [fellAsleepAt, setFellAsleepAt] = useState(() =>
    defaultManualStartInput(timezone),
  );
  const [wokeUpAt, setWokeUpAt] = useState("");
  const [includeWakeTime, setIncludeWakeTime] = useState(false);

  return (
    <form action={createNightSleepAction} className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block space-y-1.5 sm:col-span-2">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            Child
          </span>
          <select
            name="profileId"
            className="hub-input"
            value={profileId}
            onChange={(event) => setProfileId(event.target.value)}
            required
          >
            {childProfiles.map((profile) => (
              <option key={profile.id} value={profile.id}>
                {profile.name}
              </option>
            ))}
          </select>
        </label>
        <label className="block space-y-1.5">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            Fell asleep
          </span>
          <input
            type="datetime-local"
            name="fellAsleepAt"
            className="hub-input"
            value={fellAsleepAt}
            onChange={(event) => setFellAsleepAt(event.target.value)}
            required
          />
        </label>
        <label className="block space-y-1.5 sm:col-span-2">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            Woke up
          </span>
          <label className="flex items-center gap-2 text-sm font-bold text-[var(--muted)]">
            <input
              type="checkbox"
              checked={includeWakeTime}
              onChange={(event) => setIncludeWakeTime(event.target.checked)}
            />
            Set wake time
          </label>
          {includeWakeTime ? (
            <input
              type="datetime-local"
              name="wokeUpAt"
              className="hub-input"
              value={wokeUpAt}
              onChange={(event) => setWokeUpAt(event.target.value)}
            />
          ) : (
            <span className="text-xs font-bold text-[var(--muted)]">
              Leave unset if they&apos;re still asleep. Add the wake time later.
            </span>
          )}
        </label>
      </div>
      <button type="submit" className="hub-button">
        {includeWakeTime ? "Add night sleep" : "Start bedtime"}
      </button>
    </form>
  );
}

export function ManualNapForm({
  childProfiles,
  timezone,
}: {
  childProfiles: ChildProfile[];
  timezone: string;
}) {
  const defaultProfileId = childProfiles[0]?.id ?? "";
  const [profileId, setProfileId] = useState(defaultProfileId);
  const [startedAt, setStartedAt] = useState(() =>
    defaultManualStartInput(timezone),
  );
  const [endedAt, setEndedAt] = useState("");

  return (
    <form action={createManualNapAction} className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block space-y-1.5">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            Child
          </span>
          <select
            name="profileId"
            className="hub-input"
            value={profileId}
            onChange={(event) => setProfileId(event.target.value)}
            required
          >
            {childProfiles.map((profile) => (
              <option key={profile.id} value={profile.id}>
                {profile.name}
              </option>
            ))}
          </select>
        </label>
        <div />
        <label className="block space-y-1.5">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            Start time
          </span>
          <input
            type="datetime-local"
            name="startedAt"
            className="hub-input"
            value={startedAt}
            onChange={(event) => setStartedAt(event.target.value)}
            required
          />
        </label>
        <label className="block space-y-1.5">
          <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
            End time
          </span>
          <input
            type="datetime-local"
            name="endedAt"
            className="hub-input"
            value={endedAt}
            onChange={(event) => setEndedAt(event.target.value)}
          />
          <span className="text-xs font-bold text-[var(--muted)]">
            Leave blank if the nap is still in progress.
          </span>
        </label>
      </div>
      <button type="submit" className="hub-button">
        Add nap
      </button>
    </form>
  );
}

export function BedtimeChildRow({
  profile,
  activeNight,
  timezone,
}: {
  profile: ChildProfile;
  activeNight?: SleepItem;
  timezone: string;
}) {
  const startedLabel = activeNight
    ? formatInTimeZone(new Date(activeNight.startedAt), timezone, "h:mm a")
    : null;

  return (
    <div className="rounded-2xl bg-[var(--tile)] p-4">
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="h-3 w-3 shrink-0 rounded-full"
            style={profileColorStyle(profile.color)}
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold">{profile.name}</p>
            {activeNight ? (
              <p className="text-xs font-bold text-[var(--muted)]">
                In bed since {startedLabel} ·{" "}
                <LiveDuration
                  startedAt={activeNight.startedAt}
                  endedAt={activeNight.endedAt}
                />
              </p>
            ) : (
              <p className="text-xs font-bold text-[var(--muted)]">
                No active bedtime
              </p>
            )}
          </div>
        </div>

        {activeNight ? (
          <form action={endNapAction.bind(null, activeNight.id)}>
            <button type="submit" className="hub-button secondary !min-h-9 !px-3 text-xs">
              Log wake up
            </button>
          </form>
        ) : (
          <form action={startNightSleepAction.bind(null, profile.id)}>
            <button type="submit" className="hub-button secondary !min-h-9 !px-3 text-xs">
              Start bedtime
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

export function SleepDashboardRow({
  profile,
  logs,
  localDate,
  timezone,
}: {
  profile: ChildProfile;
  logs: SleepItem[];
  localDate: string;
  timezone: string;
}) {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  const records = logs.map((log) => ({
    id: log.id,
    profileId: log.profileId,
    kind: log.kind ?? "nap",
    localDate: log.localDate,
    startedAt: new Date(log.startedAt),
    endedAt: log.endedAt ? new Date(log.endedAt) : null,
  }));

  const status = getChildDashboardSleepStatus(
    records,
    profile.id,
    localDate,
    timezone,
    now,
  );
  const secondary = formatDashboardSleepSecondary(status);

  const primaryLabel = (() => {
    if (status.state === "napping") {
      return (
        <>
          Nap · asleep{" "}
          <LiveDuration
            startedAt={status.startedAt!.toISOString()}
            endedAt={null}
          />
        </>
      );
    }
    if (status.state === "in_bed") {
      const startedLabel = formatInTimeZone(
        status.startedAt!,
        timezone,
        "h:mm a",
      );
      return (
        <>
          In bed since {startedLabel} ·{" "}
          <LiveDuration
            startedAt={status.startedAt!.toISOString()}
            endedAt={null}
          />
        </>
      );
    }
    if (status.state === "awake") {
      return `Awake ${formatSleepDuration(status.durationMinutes)}`;
    }
    return "No sleep logged today";
  })();

  const actionLabel =
    status.state === "in_bed"
      ? "Log wake up"
      : status.state === "napping"
        ? "End nap"
        : null;

  return (
    <div className="rounded-2xl bg-[var(--tile-quiet)] p-3">
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="h-3 w-3 shrink-0 rounded-full"
            style={profileColorStyle(profile.color)}
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold">{profile.name}</p>
            <p className="text-xs font-bold text-[var(--muted)]">{primaryLabel}</p>
            {secondary ? (
              <p className="text-xs font-bold text-[var(--muted)]">{secondary}</p>
            ) : null}
          </div>
        </div>

        {status.activeLogId && actionLabel ? (
          <form action={endNapAction.bind(null, status.activeLogId)}>
            <button
              type="submit"
              className="hub-button secondary !min-h-8 !px-2 text-xs"
            >
              {actionLabel}
            </button>
          </form>
        ) : null}
      </div>
    </div>
  );
}

export function NapChildRow({
  profile,
  activeNap,
  timezone,
  compact = false,
  todayLogs,
  localDate,
}: {
  profile: ChildProfile;
  activeNap?: SleepItem;
  timezone: string;
  compact?: boolean;
  todayLogs?: SleepItem[];
  localDate?: string;
}) {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    if (!compact || !localDate) return;
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, [compact, localDate]);

  const startedLabel = activeNap
    ? formatInTimeZone(new Date(activeNap.startedAt), timezone, "h:mm a")
    : null;
  const summaryLine =
    compact && localDate && todayLogs
      ? formatChildTodaySleepSummary(
          todayLogs.map((log) => ({
            kind: log.kind ?? "nap",
            startedAt: new Date(log.startedAt),
            endedAt: log.endedAt ? new Date(log.endedAt) : null,
          })),
          now,
          { isActive: !!activeNap },
        )
      : null;

  return (
    <div
      className={
        compact
          ? "rounded-2xl bg-[var(--tile-quiet)] p-3"
          : "rounded-2xl bg-[var(--tile)] p-4"
      }
    >
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="h-3 w-3 shrink-0 rounded-full"
            style={profileColorStyle(profile.color)}
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold">{profile.name}</p>
            {activeNap ? (
              <p className="text-xs font-bold text-[var(--muted)]">
                Asleep since {startedLabel} ·{" "}
                <LiveDuration
                  startedAt={activeNap.startedAt}
                  endedAt={activeNap.endedAt}
                />
              </p>
            ) : !compact ? (
              <p className="text-xs font-bold text-[var(--muted)]">
                No active nap
              </p>
            ) : null}
            {summaryLine ? (
              <p className="text-xs font-bold text-[var(--muted)]">
                {summaryLine}
              </p>
            ) : null}
          </div>
        </div>

        {activeNap ? (
          <form action={endNapAction.bind(null, activeNap.id)}>
            <button type="submit" className="hub-button secondary !min-h-9 !px-3 text-xs">
              End nap
            </button>
          </form>
        ) : (
          <form action={startNapAction.bind(null, profile.id)}>
            <button type="submit" className="hub-button secondary !min-h-9 !px-3 text-xs">
              Start nap
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

export function NapHistoryRow({
  nap,
  profileName,
  profileColor,
  timezone,
}: {
  nap: SleepItem;
  profileName: string;
  profileColor: string;
  timezone: string;
}) {
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [startedAt, setStartedAt] = useState(() =>
    toLocalDateTimeInput(new Date(nap.startedAt), timezone),
  );
  const [endedAt, setEndedAt] = useState(() =>
    nap.endedAt ? toLocalDateTimeInput(new Date(nap.endedAt), timezone) : "",
  );
  const [includeEndTime, setIncludeEndTime] = useState(() => nap.endedAt != null);

  useEffect(() => {
    if (editing) return;
    setStartedAt(toLocalDateTimeInput(new Date(nap.startedAt), timezone));
    setEndedAt(
      nap.endedAt ? toLocalDateTimeInput(new Date(nap.endedAt), timezone) : "",
    );
    setIncludeEndTime(nap.endedAt != null);
    setSaveError(null);
  }, [nap.startedAt, nap.endedAt, nap.id, timezone, editing]);

  function beginEditing() {
    setStartedAt(toLocalDateTimeInput(new Date(nap.startedAt), timezone));
    setEndedAt(
      nap.endedAt ? toLocalDateTimeInput(new Date(nap.endedAt), timezone) : "",
    );
    setIncludeEndTime(nap.endedAt != null);
    setSaveError(null);
    setEditing(true);
  }

  async function handleSave(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setSaveError(null);
    try {
      const formData = new FormData(event.currentTarget);
      if (!includeEndTime) {
        formData.delete("endedAt");
      }
      await updateNapAction(nap.id, formData);
      setEditing(false);
    } catch (error) {
      setSaveError(
        error instanceof Error ? error.message : "Could not save sleep entry.",
      );
    } finally {
      setSaving(false);
    }
  }

  const kind = nap.kind ?? "nap";
  const startFieldLabel = kind === "night" ? "Fell asleep" : "Start time";
  const endFieldLabel = kind === "night" ? "Woke up" : "End time";
  const startedLabel = formatInTimeZone(
    new Date(nap.startedAt),
    timezone,
    "h:mm a",
  );
  const endedLabel = nap.endedAt
    ? formatInTimeZone(new Date(nap.endedAt), timezone, "h:mm a")
    : kind === "night"
      ? "Still asleep"
      : "In progress";

  return (
    <div className="rounded-2xl bg-[var(--tile-quiet)] px-4 py-3">
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="h-3 w-3 shrink-0 rounded-full"
            style={profileColorStyle(profileColor)}
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold">{profileName}</p>
            {!editing && (
              <p className="text-xs font-bold text-[var(--muted)]">
                {sleepKindLabel(kind)} · {startedLabel} – {endedLabel} ·{" "}
                <LiveDuration
                  startedAt={nap.startedAt}
                  endedAt={nap.endedAt}
                />
              </p>
            )}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          {!editing && nap.endedAt == null && (
            <form action={endNapAction.bind(null, nap.id)}>
              <button type="submit" className="hub-button secondary !min-h-8 !px-2 text-xs">
                {kind === "night" ? "Wake up" : "End"}
              </button>
            </form>
          )}
          {!editing && (
            <button
              type="button"
              className="text-xs font-bold text-[var(--sage)]"
              onClick={beginEditing}
            >
              Edit
            </button>
          )}
          {!editing && (
            <form action={deleteNapAction.bind(null, nap.id)}>
              <button
                type="submit"
                className="text-xs font-bold text-[var(--coral)]"
              >
                Delete
              </button>
            </form>
          )}
        </div>
      </div>

      {editing && (
        <form
          onSubmit={handleSave}
          className="mt-4 space-y-3 border-t border-[var(--line)] pt-4"
        >
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block space-y-1.5">
              <span className="text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
                {startFieldLabel}
              </span>
              <input
                type="datetime-local"
                name="startedAt"
                className="hub-input"
                value={startedAt}
                onChange={(event) => setStartedAt(event.target.value)}
                required
              />
            </label>
            <div className="space-y-2">
              <label className="flex items-center gap-2 text-xs font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
                <input
                  type="checkbox"
                  checked={includeEndTime}
                  onChange={(event) => setIncludeEndTime(event.target.checked)}
                />
                Set {endFieldLabel.toLowerCase()}
              </label>
              {includeEndTime ? (
                <input
                  type="datetime-local"
                  name="endedAt"
                  className="hub-input"
                  value={endedAt}
                  onChange={(event) => setEndedAt(event.target.value)}
                />
              ) : (
                <p className="text-xs font-bold text-[var(--muted)]">
                  Leave unset if still asleep or in progress.
                </p>
              )}
            </div>
          </div>
          {saveError ? (
            <p className="text-xs font-bold text-[var(--coral)]">{saveError}</p>
          ) : null}
          <div className="flex gap-2">
            <button
              type="submit"
              className="hub-button secondary !min-h-9 !px-4 text-xs"
              disabled={saving}
            >
              {saving ? "Saving…" : "Save"}
            </button>
            <button
              type="button"
              className="hub-button secondary !min-h-9 !px-4 text-xs"
              onClick={() => setEditing(false)}
              disabled={saving}
            >
              Cancel
            </button>
          </div>
        </form>
      )}
    </div>
  );
}

type SleepDayHistoryProps = {
  childProfiles: ChildProfile[];
  logs: SleepItem[];
  localDate: string;
  timezone: string;
  title?: string;
};

export function SleepDayHistorySection({
  childProfiles,
  logs,
  localDate,
  timezone,
  title = "Logged sleep",
}: SleepDayHistoryProps) {
  const dayLogs = useMemo(() => {
    const records = logs.map((log) => ({
      ...log,
      kind: log.kind ?? "nap",
      startedAt: new Date(log.startedAt),
      endedAt: log.endedAt ? new Date(log.endedAt) : null,
    }));
    return sleepLogsOnDate(records, localDate, timezone).sort(
      (left, right) => left.startedAt.getTime() - right.startedAt.getTime(),
    );
  }, [logs, localDate, timezone]);

  if (!dayLogs.length) return null;

  return (
    <div className="hub-card p-5 max-md:p-4">
      <h3 className="font-display text-2xl font-semibold">{title}</h3>
      <p className="mt-2 text-sm text-[var(--muted)]">
        Tap Edit on any entry to change start or end times after logging.
      </p>
      <div className="mt-4 space-y-2">
        {dayLogs.map((log) => {
          const profile = childProfiles.find((item) => item.id === log.profileId);
          if (!profile) return null;
          return (
            <NapHistoryRow
              key={log.id}
              nap={{
                id: log.id,
                profileId: log.profileId,
                kind: log.kind,
                localDate: log.localDate,
                startedAt: log.startedAt.toISOString(),
                endedAt: log.endedAt?.toISOString() ?? null,
              }}
              profileName={profile.name}
              profileColor={profile.color}
              timezone={timezone}
            />
          );
        })}
      </div>
    </div>
  );
}
