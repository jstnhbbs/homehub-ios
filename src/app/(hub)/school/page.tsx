import { and, asc, eq } from "drizzle-orm";
import { BookOpen, CalendarPlus, Plus, Trash2 } from "lucide-react";
import {
  addSchoolPeriod,
  addSchoolScheduleEntry,
  addSchoolSubject,
  deleteSchoolScheduleEntry,
} from "@/app/actions";
import { db } from "@/db/client";
import {
  profiles,
  schoolPeriods,
  schoolScheduleEntries,
  schoolSubjects,
} from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";
import { nextSchoolDate, parsePackItems, weekdayForLocalDate, WEEKDAYS } from "@/lib/school";

export default async function SchoolPage() {
  const household = await requireHousehold();
  const today = localDateIn(household.timezone);
  const nextDate = nextSchoolDate(today);
  const nextWeekday = weekdayForLocalDate(nextDate);
  const [subjects, periods, entries, children] = await Promise.all([
    db
      .select()
      .from(schoolSubjects)
      .where(eq(schoolSubjects.householdId, household.id))
      .orderBy(asc(schoolSubjects.sortOrder), asc(schoolSubjects.name)),
    db
      .select()
      .from(schoolPeriods)
      .where(eq(schoolPeriods.householdId, household.id))
      .orderBy(asc(schoolPeriods.startsAt), asc(schoolPeriods.sortOrder)),
    db
      .select({
        id: schoolScheduleEntries.id,
        weekday: schoolScheduleEntries.weekday,
        room: schoolScheduleEntries.room,
        notes: schoolScheduleEntries.notes,
        profileId: schoolScheduleEntries.profileId,
        subjectName: schoolSubjects.name,
        subjectColor: schoolSubjects.color,
        packItems: schoolSubjects.packItems,
        periodLabel: schoolPeriods.label,
        startsAt: schoolPeriods.startsAt,
        endsAt: schoolPeriods.endsAt,
      })
      .from(schoolScheduleEntries)
      .innerJoin(schoolSubjects, eq(schoolScheduleEntries.subjectId, schoolSubjects.id))
      .innerJoin(schoolPeriods, eq(schoolScheduleEntries.periodId, schoolPeriods.id))
      .where(eq(schoolScheduleEntries.householdId, household.id))
      .orderBy(asc(schoolScheduleEntries.weekday), asc(schoolPeriods.startsAt)),
    db
      .select()
      .from(profiles)
      .where(and(eq(profiles.householdId, household.id), eq(profiles.profileType, "child")))
      .orderBy(asc(profiles.sortOrder)),
  ]);
  const nextEntries = entries.filter((entry) => entry.weekday === nextWeekday);
  const packItems = Array.from(
    new Set(nextEntries.flatMap((entry) => parsePackItems(entry.packItems))),
  );

  return (
    <div className="mx-auto max-w-6xl pb-10">
      <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
        Backpack ready
      </p>
      <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
        School schedule
      </h1>

      <div className="mt-6 grid grid-cols-[340px_1fr] gap-5 max-lg:grid-cols-1">
        <aside className="space-y-5">
          <section className="hub-card p-5">
            <h2 className="font-display text-2xl font-semibold">Tomorrow pack list</h2>
            <p className="mt-1 text-sm font-bold text-[var(--muted)]">
              {WEEKDAYS[nextWeekday]}, {nextDate}
            </p>
            <div className="mt-4 space-y-2">
              {packItems.length ? (
                packItems.map((item) => (
                  <div key={item} className="rounded-2xl bg-[var(--tile)] p-3 text-sm font-bold">
                    {item}
                  </div>
                ))
              ) : (
                <p className="rounded-2xl border border-dashed border-[var(--line)] p-4 text-sm font-bold text-[var(--muted)]">
                  Add subjects with pack items to build this automatically.
                </p>
              )}
            </div>
          </section>

          <form action={addSchoolSubject} className="hub-card grid gap-3 p-5">
            <h2 className="font-display text-2xl font-semibold">Subject</h2>
            <input name="name" className="hub-input" placeholder="Math" required />
            <input name="color" className="hub-input h-12" type="color" defaultValue="#6689a3" />
            <textarea
              name="packItems"
              className="hub-input min-h-20 resize-y"
              placeholder="Notebook&#10;Calculator"
            />
            <button className="hub-button">
              <Plus size={18} /> Add subject
            </button>
          </form>

          <form action={addSchoolPeriod} className="hub-card grid gap-3 p-5">
            <h2 className="font-display text-2xl font-semibold">Period</h2>
            <input name="label" className="hub-input" placeholder="Period 1" required />
            <div className="grid grid-cols-2 gap-2">
              <input name="startsAt" className="hub-input" type="time" defaultValue="08:00" required />
              <input name="endsAt" className="hub-input" type="time" defaultValue="08:45" required />
            </div>
            <button className="hub-button">
              <Plus size={18} /> Add period
            </button>
          </form>
        </aside>

        <main className="space-y-5">
          <form action={addSchoolScheduleEntry} className="hub-card grid gap-3 p-5">
            <h2 className="font-display text-2xl font-semibold">Add class slot</h2>
            <div className="grid grid-cols-4 gap-3 max-md:grid-cols-2 max-sm:grid-cols-1">
              <select name="weekday" className="hub-input" defaultValue="1">
                {WEEKDAYS.map((day, index) => (
                  <option key={day} value={index}>
                    {day}
                  </option>
                ))}
              </select>
              <select name="periodId" className="hub-input" required>
                <option value="">Period</option>
                {periods.map((period) => (
                  <option key={period.id} value={period.id}>
                    {period.label}
                  </option>
                ))}
              </select>
              <select name="subjectId" className="hub-input" required>
                <option value="">Subject</option>
                {subjects.map((subject) => (
                  <option key={subject.id} value={subject.id}>
                    {subject.name}
                  </option>
                ))}
              </select>
              <select name="profileId" className="hub-input" defaultValue="">
                <option value="">Any child</option>
                {children.map((child) => (
                  <option key={child.id} value={child.id}>
                    {child.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="grid grid-cols-[180px_1fr_auto] gap-3 max-sm:grid-cols-1">
              <input name="room" className="hub-input" placeholder="Room" />
              <input name="notes" className="hub-input" placeholder="Notes" />
              <button className="hub-button px-5">
                <CalendarPlus size={18} /> Save slot
              </button>
            </div>
          </form>

          <section className="hub-card p-5">
            <h2 className="font-display text-2xl font-semibold">Weekly rhythm</h2>
            <div className="mt-4 grid grid-cols-5 gap-3 max-xl:grid-cols-3 max-md:grid-cols-1">
              {WEEKDAYS.slice(1, 6).map((day, index) => {
                const weekday = index + 1;
                const dayEntries = entries.filter((entry) => entry.weekday === weekday);
                return (
                  <div key={day} className="rounded-2xl bg-[var(--tile)] p-3">
                    <h3 className="font-bold">{day}</h3>
                    <div className="mt-3 space-y-2">
                      {dayEntries.length ? (
                        dayEntries.map((entry) => (
                          <div key={entry.id} className="rounded-xl bg-[var(--surface-strong)] p-3">
                            <div className="flex items-start justify-between gap-2">
                              <div className="min-w-0">
                                <p className="truncate text-sm font-bold" style={{ color: entry.subjectColor }}>
                                  {entry.subjectName}
                                </p>
                                <p className="text-xs font-semibold text-[var(--muted)]">
                                  {entry.periodLabel} · {entry.startsAt}-{entry.endsAt}
                                </p>
                              </div>
                              <form action={deleteSchoolScheduleEntry.bind(null, entry.id)}>
                                <button type="submit" aria-label={`Delete ${entry.subjectName}`}>
                                  <Trash2 size={15} className="text-[var(--muted)]" />
                                </button>
                              </form>
                            </div>
                            {(entry.room || entry.notes) && (
                              <p className="mt-2 text-xs text-[var(--muted)]">
                                {[entry.room, entry.notes].filter(Boolean).join(" · ")}
                              </p>
                            )}
                          </div>
                        ))
                      ) : (
                        <p className="text-sm font-semibold text-[var(--muted)]">
                          No classes yet.
                        </p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </section>

          <section className="hub-card p-5">
            <div className="flex items-center gap-2">
              <BookOpen size={20} className="text-[var(--sage)]" />
              <h2 className="font-display text-2xl font-semibold">Subjects</h2>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-3 max-md:grid-cols-1">
              {subjects.map((subject) => (
                <div key={subject.id} className="rounded-2xl bg-[var(--tile)] p-4">
                  <p className="font-bold" style={{ color: subject.color }}>
                    {subject.name}
                  </p>
                  <p className="mt-2 whitespace-pre-wrap text-sm text-[var(--muted)]">
                    {subject.packItems || "No pack items"}
                  </p>
                </div>
              ))}
            </div>
          </section>
        </main>
      </div>
    </div>
  );
}
