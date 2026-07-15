import { and, asc, eq } from "drizzle-orm";
import { fromZonedTime } from "date-fns-tz";
import {
  ArrowRight,
  CalendarDays,
  CheckSquare2,
  ClipboardCheck,
  Soup,
} from "lucide-react";
import Link from "next/link";
import { toggleChore, toggleRoutineStep } from "@/app/actions";
import { CalendarSync } from "@/components/calendar-sync";
import { CheckItem } from "@/components/check-item";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  choreCompletions,
  chores,
  meals,
  profiles,
  routineCompletions,
  routines,
  routineSteps,
} from "@/db/schema";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { localDateIn, weekKey } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";

export default async function DashboardPage() {
  const household = await requireHousehold();
  const localDate = localDateIn(household.timezone);
  const dayStart = fromZonedTime(`${localDate}T00:00:00`, household.timezone);
  const dayEnd = fromZonedTime(`${localDate}T23:59:59`, household.timezone);
  const weeklyKey = weekKey(dayStart);

  const [
    familyProfiles,
    routineRows,
    routineDone,
    choreRows,
    choreDone,
    todayMeals,
    eventRows,
    connectionRows,
  ] = await Promise.all([
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
    db
      .select({
        id: routineSteps.id,
        label: routineSteps.label,
        routineName: routines.name,
        period: routines.period,
        profileId: routines.profileId,
      })
      .from(routineSteps)
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(eq(routines.householdId, household.id))
      .orderBy(asc(routines.sortOrder), asc(routineSteps.sortOrder)),
    db
      .select({ stepId: routineCompletions.stepId })
      .from(routineCompletions)
      .innerJoin(routineSteps, eq(routineCompletions.stepId, routineSteps.id))
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(
        and(
          eq(routines.householdId, household.id),
          eq(routineCompletions.localDate, localDate),
        ),
      ),
    db
      .select()
      .from(chores)
      .where(eq(chores.householdId, household.id))
      .orderBy(asc(chores.sortOrder)),
    db
      .select({
        choreId: choreCompletions.choreId,
        periodKey: choreCompletions.periodKey,
      })
      .from(choreCompletions)
      .innerJoin(chores, eq(choreCompletions.choreId, chores.id))
      .where(eq(chores.householdId, household.id)),
    db
      .select()
      .from(meals)
      .where(
        and(
          eq(meals.householdId, household.id),
          eq(meals.localDate, localDate),
        ),
      ),
    db
      .select({
        id: calendarEvents.id,
        rawIcal: calendarEvents.rawIcal,
        color: calendars.color,
        calendarName: calendars.displayName,
      })
      .from(calendarEvents)
      .innerJoin(calendars, eq(calendarEvents.calendarId, calendars.id))
      .innerJoin(
        calendarConnections,
        eq(calendars.connectionId, calendarConnections.id),
      )
      .where(
        and(
          eq(calendarConnections.householdId, household.id),
          eq(calendars.enabled, true),
        ),
      ),
    db
      .select()
      .from(calendarConnections)
      .where(eq(calendarConnections.householdId, household.id))
      .limit(1),
  ]);

  const doneSteps = new Set(routineDone.map((item) => item.stepId));
  const profileMap = new Map(familyProfiles.map((profile) => [profile.id, profile]));
  const schedule = eventRows
    .flatMap((event) =>
      expandIcalEvent(event.rawIcal, dayStart, dayEnd).map((occurrence) => ({
        ...occurrence,
        eventId: event.id,
        color: event.color,
        calendarName: event.calendarName,
      })),
    )
    .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
  const currentConnection = connectionRows[0];
  const mealSlots = ["breakfast", "lunch", "dinner", "snack"] as const;

  return (
    <div className="mx-auto max-w-[1500px]">
      <div className="mb-5 flex items-center justify-between gap-4 max-md:flex-col max-md:items-start">
        <div className="min-w-0">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Good day, family
          </p>
          <h1 className="font-display text-4xl font-semibold max-md:text-3xl">
            Here’s what’s happening today.
          </h1>
        </div>
        <CalendarSync
          connected={Boolean(currentConnection)}
          lastSyncedAt={currentConnection?.lastSyncedAt?.toISOString()}
        />
      </div>

      <div className="grid grid-cols-12 gap-5 max-md:gap-3">
        <section className="hub-card col-span-5 min-h-[310px] p-5 max-md:col-span-12 max-md:min-h-0 max-md:p-4">
          <CardTitle
            icon={CalendarDays}
            title="Today’s schedule"
            href="/calendar"
          />
          <div className="mt-4 space-y-2">
            {schedule.length ? (
              schedule.slice(0, 5).map((event, index) => (
                <div
                  key={`${event.eventId}-${event.startsAt.toISOString()}-${index}`}
                  className="flex min-h-14 items-center gap-3 rounded-2xl bg-white/65 px-3"
                >
                  <span
                    className="h-9 w-1.5 rounded-full"
                    style={{ background: event.color }}
                  />
                  <div className="min-w-0">
                    <p className="truncate font-bold">{event.title}</p>
                    <p className="text-xs text-[var(--muted)]">
                      {event.allDay
                        ? "All day"
                        : new Intl.DateTimeFormat("en-US", {
                            timeZone: household.timezone,
                            hour: "numeric",
                            minute: "2-digit",
                          }).format(event.startsAt)}
                      {" · "}
                      {event.calendarName}
                    </p>
                  </div>
                </div>
              ))
            ) : (
              <EmptyState
                text={
                  currentConnection
                    ? "Nothing on the calendar today."
                    : "Connect Apple Calendar to see today’s events."
                }
                href="/settings/calendar"
              />
            )}
          </div>
        </section>

        <section className="hub-card col-span-4 min-h-[310px] p-5 max-md:col-span-12 max-md:min-h-0 max-md:p-4">
          <CardTitle
            icon={ClipboardCheck}
            title="Today’s routines"
            href="/routines"
          />
          <div className="scrollbar-none mt-4 max-h-[245px] space-y-2 overflow-auto">
            {routineRows.length ? (
              routineRows.slice(0, 5).map((step) => {
                const profile = step.profileId
                  ? profileMap.get(step.profileId)
                  : undefined;
                return (
                  <CheckItem
                    key={step.id}
                    label={step.label}
                    detail={profile?.name ?? step.routineName}
                    color={profile?.color}
                    initialChecked={doneSteps.has(step.id)}
                    onToggle={toggleRoutineStep.bind(
                      null,
                      step.id,
                      localDate,
                    )}
                  />
                );
              })
            ) : (
              <EmptyState text="Add a morning or bedtime routine." href="/routines" />
            )}
          </div>
        </section>

        <section className="hub-card col-span-3 min-h-[310px] bg-[var(--sun-soft)]/50 p-5 max-md:col-span-12 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={Soup} title="Today’s meals" href="/meals" />
          <div className="mt-5 space-y-3">
            {mealSlots.map((slot) => {
              const meal = todayMeals.find((item) => item.slot === slot);
              return (
                <div key={slot}>
                  <p className="text-[10px] font-extrabold uppercase tracking-[0.16em] text-[var(--muted)]">
                    {slot}
                  </p>
                  <p className="mt-0.5 truncate font-bold">
                    {meal?.title || "Not planned"}
                  </p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="hub-card col-span-7 min-h-[245px] p-5 max-md:col-span-12 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={CheckSquare2} title="Chores" href="/chores" />
          <div className="mt-4 grid grid-cols-2 gap-2 max-sm:grid-cols-1">
            {choreRows.length ? (
              choreRows.slice(0, 4).map((chore) => {
                const profile = chore.profileId
                  ? profileMap.get(chore.profileId)
                  : undefined;
                const periodKey =
                  chore.cadence === "weekly" ? weeklyKey : localDate;
                const checked = choreDone.some(
                  (item) =>
                    item.choreId === chore.id && item.periodKey === periodKey,
                );
                return (
                  <CheckItem
                    key={chore.id}
                    label={chore.title}
                    detail={profile?.name ?? "Anyone"}
                    color={profile?.color}
                    initialChecked={checked}
                    onToggle={toggleChore.bind(null, chore.id, periodKey)}
                  />
                );
              })
            ) : (
              <div className="col-span-2">
                <EmptyState text="Add the first family chore." href="/chores" />
              </div>
            )}
          </div>
        </section>

        <section className="hub-card col-span-5 min-h-[245px] overflow-hidden p-5 max-md:col-span-12 max-md:min-h-0 max-md:p-4">
          <h2 className="font-display text-2xl font-semibold">Family</h2>
          <div className="mt-5 flex flex-wrap items-center gap-4">
            {familyProfiles.map((profile) => (
              <div key={profile.id} className="text-center">
                <div
                  className="mx-auto flex h-16 w-16 items-center justify-center rounded-full text-xl font-extrabold text-white"
                  style={{ background: profile.color }}
                >
                  {profile.name.slice(0, 1).toUpperCase()}
                </div>
                <p className="mt-2 text-sm font-bold">{profile.name}</p>
              </div>
            ))}
            {!familyProfiles.length && (
              <EmptyState text="Add child profiles in settings." href="/settings" />
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function CardTitle({
  icon: Icon,
  title,
  href,
}: {
  icon: typeof CalendarDays;
  title: string;
  href: string;
}) {
  return (
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-2">
        <Icon size={20} className="text-[var(--sage)]" />
        <h2 className="font-display text-2xl font-semibold max-md:text-xl">
          {title}
        </h2>
      </div>
      <Link
        href={href}
        aria-label={`Open ${title}`}
        className="flex h-9 w-9 items-center justify-center rounded-full bg-black/[0.04]"
      >
        <ArrowRight size={17} />
      </Link>
    </div>
  );
}

function EmptyState({ text, href }: { text: string; href: string }) {
  return (
    <div className="flex min-h-24 items-center justify-center rounded-2xl border border-dashed border-[var(--line)] p-4 text-center">
      <Link href={href} className="text-sm font-bold text-[var(--muted)]">
        {text}
      </Link>
    </div>
  );
}
