import { and, asc, eq, gte, isNotNull, lte, or } from "drizzle-orm";
import { fromZonedTime } from "date-fns-tz";
import {
  ArrowRight,
  Bell,
  BookOpen,
  CalendarDays,
  CheckSquare2,
  ClipboardCheck,
  Cookie,
  Gift,
  ListChecks,
  Moon,
  StickyNote,
  Soup,
  Sun,
} from "lucide-react";
import Link from "next/link";
import {
  toggleChore,
  toggleRoutineStep,
  toggleShoppingItem,
  toggleSnack,
} from "@/app/actions";
import { calendarSyncStatus } from "@/lib/calendar/connections";
import { CalendarSync } from "@/components/calendar-sync";
import { CheckItem } from "@/components/check-item";
import { SleepDashboardRow } from "@/components/nap-controls";
import { TodaySchedule } from "@/components/today-schedule";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  choreCompletions,
  chores,
  familyBirthdays,
  householdNotes,
  meals,
  profiles,
  routineCompletions,
  routines,
  routineSteps,
  schoolPeriods,
  schoolScheduleEntries,
  schoolSubjects,
  shoppingItems,
  snackCompletions,
} from "@/db/schema";
import {
  birthdayEventsInRange,
} from "@/lib/birthdays";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { localDateIn, weekKey } from "@/lib/dates";
import { isChoreDueOnDate } from "@/lib/chores";
import { parseSnackOptions, sortSnackOptions } from "@/lib/meals/snacks";
import { fetchTodayNaps } from "@/lib/naps/store";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import { upcomingFamilyBirthdays } from "@/lib/family-birthdays";
import { nextSchoolDate, parsePackItems, weekdayForLocalDate, WEEKDAYS } from "@/lib/school";
import { fetchHouseholdWeather } from "@/lib/weather";

export default async function DashboardPage() {
  const household = await requireHousehold();
  const localDate = localDateIn(household.timezone);
  const dayStart = fromZonedTime(`${localDate}T00:00:00`, household.timezone);
  const dayEnd = fromZonedTime(`${localDate}T23:59:59`, household.timezone);
  const weeklyKey = weekKey(dayStart);
  const nextClassDate = nextSchoolDate(localDate);
  const nextClassWeekday = weekdayForLocalDate(nextClassDate);

  const [
    familyProfiles,
    routineRows,
    routineDone,
    choreRows,
    choreDone,
    todayMeals,
    eventRows,
    connectionRows,
    snackDone,
    napData,
    shoppingRows,
    noteRows,
    birthdayRows,
    schoolRows,
    weather,
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
          or(
            isNotNull(calendarEvents.recurrenceRule),
            and(
              lte(calendarEvents.startsAt, dayEnd),
              gte(calendarEvents.endsAt, dayStart),
            ),
          ),
        ),
      ),
    db
      .select()
      .from(calendarConnections)
      .where(eq(calendarConnections.householdId, household.id)),
    db
      .select({ snackLabel: snackCompletions.snackLabel })
      .from(snackCompletions)
      .where(
        and(
          eq(snackCompletions.householdId, household.id),
          eq(snackCompletions.localDate, localDate),
        ),
      ),
    fetchTodayNaps(household),
    db
      .select()
      .from(shoppingItems)
      .where(
        and(
          eq(shoppingItems.householdId, household.id),
          eq(shoppingItems.checked, false),
        ),
      )
      .orderBy(asc(shoppingItems.category), asc(shoppingItems.createdAt)),
    db
      .select()
      .from(householdNotes)
      .where(eq(householdNotes.householdId, household.id))
      .orderBy(asc(householdNotes.createdAt)),
    db
      .select()
      .from(familyBirthdays)
      .where(eq(familyBirthdays.householdId, household.id)),
    db
      .select({
        id: schoolScheduleEntries.id,
        subjectName: schoolSubjects.name,
        packItems: schoolSubjects.packItems,
        periodLabel: schoolPeriods.label,
        startsAt: schoolPeriods.startsAt,
      })
      .from(schoolScheduleEntries)
      .innerJoin(schoolSubjects, eq(schoolScheduleEntries.subjectId, schoolSubjects.id))
      .innerJoin(schoolPeriods, eq(schoolScheduleEntries.periodId, schoolPeriods.id))
      .where(
        and(
          eq(schoolScheduleEntries.householdId, household.id),
          eq(schoolScheduleEntries.weekday, nextClassWeekday),
        ),
      )
      .orderBy(asc(schoolPeriods.startsAt)),
    fetchHouseholdWeather({
      location: household.weatherLocation,
      latitude: household.weatherLatitude,
      longitude: household.weatherLongitude,
    }),
  ]);

  const doneSteps = new Set(routineDone.map((item) => item.stepId));
  const profileMap = new Map(familyProfiles.map((profile) => [profile.id, profile]));
  const dueChores = choreRows.filter((chore) =>
    isChoreDueOnDate(
      chore.cadence,
      chore.days,
      localDate,
      household.timezone,
    ),
  );
  const schedule = [
    ...eventRows.flatMap((event) =>
      expandIcalEvent(
        event.rawIcal,
        dayStart,
        dayEnd,
        household.timezone,
      ).map((occurrence) => ({
        ...occurrence,
        eventId: event.id,
        color: event.color,
        calendarName: event.calendarName,
      })),
    ),
    ...birthdayEventsInRange(
      familyProfiles,
      localDate,
      localDate,
      household.timezone,
    ),
  ].sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
  const scheduleEvents = schedule.map((event) => ({
    eventId: event.eventId,
    title: event.title,
    startsAt: event.startsAt.toISOString(),
    endsAt: event.endsAt.toISOString(),
    allDay: event.allDay,
    color: event.color,
    calendarName: event.calendarName,
  }));
  const calendarStatus = calendarSyncStatus(connectionRows, household.timezone);
  const canManage = canManageHousehold(household.role);
  const mealSlots = ["breakfast", "lunch", "dinner"] as const;
  const snackEaten = new Set(snackDone.map((item) => item.snackLabel));
  const snackItems = sortSnackOptions(
    parseSnackOptions(household.snackOptions),
    snackEaten,
  );
  const childProfiles = napData.childProfiles;
  const upcomingBirthdays = upcomingFamilyBirthdays(
    [
      ...familyProfiles
        .filter((profile) => profile.birthday)
        .map((profile) => ({
          id: `profile-${profile.id}`,
          name: profile.name,
          birthDate: profile.birthday ?? "",
          color: profile.color,
        })),
      ...birthdayRows.map((birthday) => ({
        id: birthday.id,
        name: birthday.name,
        birthDate: birthday.birthDate,
        notes: birthday.notes,
        giftIdeas: birthday.giftIdeas,
        notifyDaysBefore: birthday.notifyDaysBefore,
      })),
    ],
    localDate,
    45,
  );
  const packItems = Array.from(
    new Set(schoolRows.flatMap((entry) => parsePackItems(entry.packItems))),
  );

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
        {canManage && (
          <CalendarSync
            connected={calendarStatus.connected}
            updatedLabel={calendarStatus.updatedLabel}
            lastSyncedAt={calendarStatus.lastSyncedAt}
            syncIntervalMinutes={household.calendarSyncIntervalMinutes}
          />
        )}
      </div>

      <div className="space-y-5 max-md:space-y-3">
        <div className="grid grid-cols-3 gap-5 max-md:grid-cols-1 max-md:gap-3">
        <section className="hub-card min-h-[310px] p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle
            icon={CalendarDays}
            title="Today’s Schedule"
            href="/calendar"
          />
          <div className="mt-4 space-y-2">
            <TodaySchedule
              events={scheduleEvents}
              timezone={household.timezone}
              connected={calendarStatus.connected}
              initialNow={new Date().toISOString()}
            />
          </div>
        </section>

        <section className="hub-card min-h-[310px] p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle
            icon={ClipboardCheck}
            title="Today’s Routines"
            href="/routines"
          />
          <div className="scrollbar-none mt-4 max-h-[245px] space-y-2 overflow-auto">
            {routineRows.some((step) => !doneSteps.has(step.id)) ? (
              routineRows
                .filter((step) => !doneSteps.has(step.id))
                .slice(0, 5)
                .map((step) => {
                const profile = step.profileId
                  ? profileMap.get(step.profileId)
                  : undefined;
                return (
                  <CheckItem
                    key={step.id}
                    label={step.label}
                    detail={profile?.name ?? step.routineName}
                    color={profile?.color}
                    initialChecked={false}
                    removeWhenChecked
                    onToggle={toggleRoutineStep.bind(
                      null,
                      step.id,
                      localDate,
                    )}
                  />
                );
              })
            ) : routineRows.length ? (
              <p className="rounded-2xl border border-dashed border-[var(--line)] p-4 text-center text-sm font-bold text-[var(--muted)]">
                All routines done for today!
              </p>
            ) : (
              <EmptyState text="Add a morning or bedtime routine." href="/routines" />
            )}
          </div>
        </section>

        <section className="hub-card min-h-[310px] p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={CheckSquare2} title="Chores" href="/chores" />
          <div className="scrollbar-none mt-4 max-h-[245px] space-y-2 overflow-auto">
            {dueChores.length ? (
              dueChores.slice(0, 5).map((chore) => {
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
              <EmptyState text="Add the first family chore." href="/chores" />
            )}
          </div>
        </section>
        </div>

        <div className="grid grid-cols-3 gap-5 max-md:grid-cols-1 max-md:gap-3">
        <section className="hub-card min-h-[245px] bg-[var(--sun-soft)]/50 p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={Soup} title="Today’s Meals" href="/meals" />
          <div className="mt-5 space-y-3">
            {mealSlots.map((slot) => {
              const meal = todayMeals.find((item) => item.slot === slot);
              const items = meal?.title
                ? meal.title
                    .split("\n")
                    .map((line) => line.trim())
                    .filter(Boolean)
                : [];
              return (
                <div key={slot} className="rounded-2xl bg-[var(--tile)] p-4">
                  <p className="text-[10px] font-extrabold uppercase tracking-[0.16em] text-[var(--muted)]">
                    {slot}
                  </p>
                  {items.length ? (
                    <ul className="mt-1 space-y-0.5">
                      {items.map((item, index) => (
                        <li
                          key={`${item}-${index}`}
                          className={
                            index === 0
                              ? "break-words text-sm font-bold leading-snug"
                              : "break-words text-sm leading-snug text-[var(--muted)]"
                          }
                        >
                          {index === 0 && meal?.recipeId ? (
                            <Link
                              href={`/meals/recipes/${meal.recipeId}`}
                              className="hover:text-[var(--sage)]"
                            >
                              {item}
                            </Link>
                          ) : (
                            item
                          )}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="mt-1 text-sm font-bold leading-snug">
                      Not planned
                    </p>
                  )}
                </div>
              );
            })}
          </div>
        </section>

        <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={Cookie} title="Snacks" href="/snacks" />
          <div className="mt-4 grid grid-cols-2 gap-2 max-sm:grid-cols-1">
            {snackItems.length ? (
              snackItems.slice(0, 6).map((item) => (
                <CheckItem
                  key={item}
                  label={item}
                  initialChecked={snackEaten.has(item)}
                  onToggle={toggleSnack.bind(null, localDate, item)}
                />
              ))
            ) : (
              <div className="col-span-2">
                <EmptyState text="Add snack options for the family." href="/snacks" />
              </div>
            )}
          </div>
          {snackItems.length > 0 && (
            <p className="mt-4 text-center text-sm font-bold text-[var(--muted)]">
              {snackEaten.size} of {snackItems.length} eaten today
            </p>
          )}
        </section>

        <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
          <CardTitle icon={Moon} title="Sleep" href="/sleep" />
          <div className="scrollbar-none mt-4 max-h-[180px] space-y-2 overflow-auto">
            {childProfiles.length ? (
              childProfiles.map((profile) => (
                <SleepDashboardRow
                  key={profile.id}
                  profile={profile}
                  logs={napData.logs.map((log) => ({
                    id: log.id,
                    profileId: log.profileId,
                    kind: log.kind,
                    localDate: log.localDate,
                    startedAt: log.startedAt.toISOString(),
                    endedAt: log.endedAt?.toISOString() ?? null,
                  }))}
                  localDate={napData.localDate}
                  timezone={household.timezone}
                />
              ))
            ) : (
              <EmptyState text="Add a child profile to log sleep." href="/settings" />
            )}
          </div>
          {childProfiles.length ? (
            <p className="mt-3 text-xs font-bold text-[var(--muted)]">
              Tap Sleep to log naps, bedtime, or edit times.
            </p>
          ) : null}
        </section>
        </div>

        <div className="grid grid-cols-3 gap-5 max-md:grid-cols-1 max-md:gap-3">
          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle icon={Sun} title="Weather" href="/settings/weather" />
            <div className="mt-5">
              {weather ? (
                <div>
                  <p className="text-sm font-bold text-[var(--muted)]">
                    {weather.location}
                  </p>
                  <p className="font-display mt-2 text-6xl font-semibold">
                    {weather.temperature}°
                  </p>
                  <p className="mt-2 text-sm font-bold text-[var(--muted)]">
                    {weather.label} · feels like {weather.feelsLike}°
                  </p>
                  <div className="mt-4 grid grid-cols-3 gap-2 text-center text-xs font-bold text-[var(--muted)]">
                    <span className="rounded-2xl bg-[var(--tile)] p-3">
                      High {weather.high ?? "?"}°
                    </span>
                    <span className="rounded-2xl bg-[var(--tile)] p-3">
                      Low {weather.low ?? "?"}°
                    </span>
                    <span className="rounded-2xl bg-[var(--tile)] p-3">
                      Rain {weather.precipitationChance ?? 0}%
                    </span>
                  </div>
                </div>
              ) : (
                <EmptyState text="Set the household weather location." href="/settings/weather" />
              )}
            </div>
          </section>

          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle icon={ListChecks} title="Shopping" href="/shopping" />
            <div className="mt-4 space-y-2">
              {shoppingRows.length ? (
                shoppingRows.slice(0, 4).map((item) => (
                  <CheckItem
                    key={item.id}
                    label={item.title}
                    detail={item.quantity ?? item.category}
                    initialChecked={false}
                    removeWhenChecked
                    onToggle={toggleShoppingItem.bind(null, item.id)}
                  />
                ))
              ) : (
                <EmptyState text="Start a shared shopping list." href="/shopping" />
              )}
            </div>
          </section>

          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle icon={StickyNote} title="Notes" href="/notes" />
            <div className="mt-4 space-y-3">
              {noteRows.length ? (
                noteRows.slice(0, 2).map((note) => (
                  <div
                    key={note.id}
                    className="rounded-[8px] p-4 text-[#21342f]"
                    style={{ background: note.color }}
                  >
                    <p className="truncate font-bold">{note.title}</p>
                    {note.body && (
                      <p className="mt-1 line-clamp-2 text-sm font-semibold text-[#3f504b]">
                        {note.body}
                      </p>
                    )}
                  </div>
                ))
              ) : (
                <EmptyState text="Leave a sticky household note." href="/notes" />
              )}
            </div>
          </section>
        </div>

        <div className="grid grid-cols-3 gap-5 max-md:grid-cols-1 max-md:gap-3">
          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle icon={Gift} title="Birthdays" href="/birthdays" />
            <div className="mt-4 space-y-2">
              {upcomingBirthdays.length ? (
                upcomingBirthdays.slice(0, 4).map((birthday) => (
                  <div key={birthday.id} className="rounded-2xl bg-[var(--tile)] p-4">
                    <p className="font-bold">{birthday.name}</p>
                    <p className="text-sm font-semibold text-[var(--muted)]">
                      {birthday.localDate} · {birthday.daysUntil === 0 ? "Today" : `${birthday.daysUntil} days`}
                    </p>
                  </div>
                ))
              ) : (
                <EmptyState text="Track birthdays and gift ideas." href="/birthdays" />
              )}
            </div>
          </section>

          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle icon={BookOpen} title="School" href="/school" />
            <p className="mt-4 text-sm font-bold text-[var(--muted)]">
              {WEEKDAYS[nextClassWeekday]}, {nextClassDate}
            </p>
            <div className="mt-3 space-y-2">
              {schoolRows.length ? (
                schoolRows.slice(0, 4).map((entry) => (
                  <div key={entry.id} className="rounded-2xl bg-[var(--tile)] p-3">
                    <p className="font-bold">{entry.subjectName}</p>
                    <p className="text-xs font-semibold text-[var(--muted)]">
                      {entry.periodLabel} · {entry.startsAt}
                    </p>
                  </div>
                ))
              ) : (
                <EmptyState text="Build a school schedule." href="/school" />
              )}
            </div>
            {packItems.length > 0 && (
              <p className="mt-3 line-clamp-2 text-sm font-semibold text-[var(--muted)]">
                Pack: {packItems.join(", ")}
              </p>
            )}
          </section>

          <section className="hub-card min-h-[245px] p-5 max-md:min-h-0 max-md:p-4">
            <CardTitle
              icon={Bell}
              title="Reminders"
              href="/settings/notifications"
            />
            <div className="mt-4 space-y-3">
              <p className="rounded-2xl bg-[var(--tile)] p-4 text-sm font-bold text-[var(--muted)]">
                Calendar, chore, birthday, and school reminder preferences are
                ready to tune per parent.
              </p>
              <Link href="/settings/recycle-bin" className="hub-button secondary w-fit">
                Open recycle bin
              </Link>
            </div>
          </section>
        </div>
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
        className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--tile-quiet)]"
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
