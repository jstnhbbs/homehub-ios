import { and, asc, eq } from "drizzle-orm";
import { Moon, Pencil, Plus, Sun, Sunset, Trash2 } from "lucide-react";
import {
  addRoutine,
  deleteRoutine,
  toggleRoutineStep,
  updateRoutine,
} from "@/app/actions";
import { CheckItem } from "@/components/check-item";
import { db } from "@/db/client";
import {
  profiles,
  routineCompletions,
  routines,
  routineSteps,
} from "@/db/schema";
import { groupBy } from "@/lib/group-by";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";

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
  const grouped = groupBy(routineRows, (row) => row.routineId);
  const canManage = canManageHousehold(household.role);

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
                  {rows.some((row) => row.stepId && !done.has(row.stepId)) ? (
                    rows.map(
                      (row) =>
                        row.stepId &&
                        !done.has(row.stepId) && (
                          <CheckItem
                            key={row.stepId}
                            label={row.stepLabel ?? ""}
                            color={profile?.color}
                            initialChecked={false}
                            removeWhenChecked
                            onToggle={toggleRoutineStep.bind(
                              null,
                              row.stepId,
                              localDate,
                            )}
                          />
                        ),
                    )
                  ) : (
                    rows.some((row) => row.stepId) && (
                      <p className="rounded-2xl bg-[var(--tile)] px-3 py-4 text-center text-sm font-bold text-[var(--muted)]">
                        All done for today!
                      </p>
                    )
                  )}
                </div>
                {canManage && (
                <details className="group mt-4 border-t border-[var(--line)] pt-3">
                  <summary className="flex cursor-pointer list-none items-center gap-1 text-xs font-bold text-[var(--muted)]">
                    <Pencil size={12} /> Edit {routine.routineName}
                  </summary>
                  <form
                    action={updateRoutine.bind(null, routine.routineId)}
                    className="mt-3 space-y-2 rounded-xl bg-[var(--tile)] p-3"
                  >
                    <input
                      name="name"
                      className="hub-input"
                      defaultValue={routine.routineName}
                      aria-label="Routine name"
                      required
                    />
                    <select
                      name="profileId"
                      className="hub-input"
                      defaultValue={routine.profileId ?? ""}
                      aria-label="Assign routine to"
                    >
                      <option value="">Everyone</option>
                      {familyProfiles.map((familyProfile) => (
                        <option
                          value={familyProfile.id}
                          key={familyProfile.id}
                        >
                          {familyProfile.name}
                        </option>
                      ))}
                    </select>
                    <select
                      name="period"
                      className="hub-input"
                      defaultValue={routine.period}
                      aria-label="Routine period"
                    >
                      <option value="morning">Morning</option>
                      <option value="afternoon">After school</option>
                      <option value="evening">Bedtime</option>
                    </select>
                    <textarea
                      name="steps"
                      className="hub-input min-h-36 resize-none"
                      defaultValue={rows
                        .flatMap((row) =>
                          row.stepLabel ? [row.stepLabel] : [],
                        )
                        .join("\n")}
                      aria-label="Routine steps"
                      required
                    />
                    <button className="hub-button w-full">
                      Save routine
                    </button>
                    <button
                      formAction={deleteRoutine.bind(null, routine.routineId)}
                      formNoValidate
                      className="flex w-full items-center justify-center gap-1 rounded-xl px-3 py-2 text-sm font-bold text-[var(--coral)]"
                    >
                      <Trash2 size={14} /> Delete routine
                    </button>
                  </form>
                </details>
                )}
              </section>
            );
          })}
          {!routineRows.length && (
            <div className="hub-card col-span-2 flex min-h-64 items-center justify-center p-8 text-center text-[var(--muted)] max-md:col-span-1">
              Your first routine will appear here.
            </div>
          )}
        </div>
        {canManage && (
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
        )}
      </div>
    </div>
  );
}
