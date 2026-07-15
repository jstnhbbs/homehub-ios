import { and, asc, eq } from "drizzle-orm";
import { Moon, Plus, Sun, Sunset } from "lucide-react";
import { addRoutine, toggleRoutineStep } from "@/app/actions";
import { CheckItem } from "@/components/check-item";
import { db } from "@/db/client";
import {
  profiles,
  routineCompletions,
  routines,
  routineSteps,
} from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";

const periodMeta = {
  morning: { label: "Morning", icon: Sun, color: "var(--sun-soft)" },
  afternoon: { label: "After school", icon: Sunset, color: "var(--coral-soft)" },
  evening: { label: "Bedtime", icon: Moon, color: "var(--blue-soft)" },
} as const;

export default async function RoutinesPage() {
  const household = await requireHousehold();
  const localDate = localDateIn(household.timezone);
  const [familyProfiles, routineRows, doneRows] = await Promise.all([
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
    db
      .select({
        routineId: routines.id,
        routineName: routines.name,
        period: routines.period,
        profileId: routines.profileId,
        stepId: routineSteps.id,
        stepLabel: routineSteps.label,
      })
      .from(routines)
      .leftJoin(routineSteps, eq(routines.id, routineSteps.routineId))
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
  ]);
  const done = new Set(doneRows.map((row) => row.stepId));
  const profileMap = new Map(familyProfiles.map((profile) => [profile.id, profile]));
  const grouped = Map.groupBy(routineRows, (row) => row.routineId);

  return (
    <div className="mx-auto max-w-[1400px]">
      <div>
        <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
          Small steps, smoother days
        </p>
        <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
          Routines
        </h1>
      </div>
      <div className="mt-6 grid grid-cols-[1fr_330px] gap-6 max-md:mt-4 max-md:grid-cols-1 max-md:gap-4">
        <div className="grid auto-rows-min grid-cols-2 gap-5 max-md:grid-cols-1 max-md:gap-3">
          {[...grouped.values()].map((rows) => {
            const routine = rows[0];
            const meta = periodMeta[routine.period];
            const Icon = meta.icon;
            const profile = routine.profileId
              ? profileMap.get(routine.profileId)
              : undefined;
            return (
              <section
                key={routine.routineId}
                className="hub-card p-5 max-md:p-4"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-xs font-bold uppercase tracking-wider text-[var(--muted)]">
                      {meta.label}
                    </p>
                    <h2 className="font-display text-2xl font-semibold">
                      {routine.routineName}
                    </h2>
                  </div>
                  <div
                    className="flex h-12 w-12 items-center justify-center rounded-2xl"
                    style={{ background: meta.color }}
                  >
                    <Icon size={22} />
                  </div>
                </div>
                <div className="mt-4 space-y-2">
                  {rows.map(
                    (row) =>
                      row.stepId && (
                        <CheckItem
                          key={row.stepId}
                          label={row.stepLabel ?? ""}
                          color={profile?.color}
                          initialChecked={done.has(row.stepId)}
                          onToggle={toggleRoutineStep.bind(
                            null,
                            row.stepId,
                            localDate,
                          )}
                        />
                      ),
                  )}
                </div>
              </section>
            );
          })}
          {!routineRows.length && (
            <div className="hub-card col-span-2 flex min-h-64 items-center justify-center p-8 text-center text-[var(--muted)] max-md:col-span-1">
              Your first routine will appear here.
            </div>
          )}
        </div>
        <aside className="hub-card h-fit p-5 max-md:p-4">
          <div className="flex items-center gap-2">
            <Plus size={20} className="text-[var(--sage)]" />
            <h2 className="font-display text-2xl font-semibold">New routine</h2>
          </div>
          <form action={addRoutine} className="mt-5 space-y-3">
            <input
              name="name"
              className="hub-input"
              placeholder="Bedtime routine"
              required
            />
            <select name="profileId" className="hub-input">
              <option value="">Everyone</option>
              {familyProfiles.map((profile) => (
                <option value={profile.id} key={profile.id}>
                  {profile.name}
                </option>
              ))}
            </select>
            <select name="period" className="hub-input" defaultValue="morning">
              <option value="morning">Morning</option>
              <option value="afternoon">After school</option>
              <option value="evening">Bedtime</option>
            </select>
            <textarea
              name="steps"
              className="hub-input min-h-36 resize-none"
              placeholder={"Brush teeth\nPack backpack\nPut shoes by the door"}
              required
            />
            <p className="text-xs text-[var(--muted)]">
              Put each checklist item on a new line.
            </p>
            <button className="hub-button w-full">Add routine</button>
          </form>
        </aside>
      </div>
    </div>
  );
}
