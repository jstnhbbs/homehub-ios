import { asc, eq } from "drizzle-orm";
import { Pencil, Plus, Sparkles } from "lucide-react";
import { addChore, toggleChore, updateChore } from "@/app/actions";
import { CheckItem } from "@/components/check-item";
import { ProfileAvatar } from "@/components/profile-avatar";
import { db } from "@/db/client";
import { choreCompletions, chores, profiles } from "@/db/schema";
import { localDateIn, weekKey } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";

export default async function ChoresPage() {
  const household = await requireHousehold();
  const localDate = localDateIn(household.timezone);
  const [familyProfiles, choreRows, completions] = await Promise.all([
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
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
  ]);
  const groups = [
    ...familyProfiles.map((profile) => ({
      id: profile.id,
      name: profile.name,
      color: profile.color,
      avatar: profile.avatar,
    })),
    { id: null, name: "Family", color: "#4f7c6d", avatar: "sparkles" },
  ];

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Pitch in together
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Chore chart
          </h1>
        </div>
        <div className="flex items-center gap-2 rounded-full bg-[var(--sun-soft)] px-4 py-2 text-sm font-bold">
          <Sparkles size={17} /> Every check helps
        </div>
      </div>
      <div className="mt-6 grid grid-cols-[1fr_330px] gap-6 max-md:mt-4 max-md:grid-cols-1 max-md:gap-4">
        <div className="grid auto-rows-min grid-cols-2 gap-5 max-md:grid-cols-1 max-md:gap-3">
          {groups.map((group) => {
            const assigned = choreRows.filter(
              (chore) => chore.profileId === group.id,
            );
            if (!assigned.length && group.id !== null) return null;
            return (
              <section
                key={group.id ?? "family"}
                className="hub-card p-5 max-md:p-4"
              >
                <div className="flex items-center gap-3">
                  <ProfileAvatar
                    name={group.name}
                    avatar={group.avatar}
                    color={group.color}
                    size={48}
                    className="text-lg"
                  />
                  <div>
                    <h2 className="font-display text-2xl font-semibold">
                      {group.name}
                    </h2>
                    <p className="text-xs font-bold text-[var(--muted)]">
                      {assigned.length} {assigned.length === 1 ? "chore" : "chores"}
                    </p>
                  </div>
                </div>
                <div className="mt-4 space-y-2">
                  {assigned.length ? (
                    assigned.map((chore) => {
                      const periodKey =
                        chore.cadence === "weekly"
                          ? weekKey(new Date())
                          : localDate;
                      return (
                        <div key={chore.id}>
                          <CheckItem
                            label={chore.title}
                            detail={chore.cadence}
                            color={group.color}
                            initialChecked={completions.some(
                              (item) =>
                                item.choreId === chore.id &&
                                item.periodKey === periodKey,
                            )}
                            onToggle={toggleChore.bind(
                              null,
                              chore.id,
                              periodKey,
                            )}
                          />
                          <details className="group mx-2 mt-1">
                            <summary className="flex cursor-pointer list-none items-center gap-1 text-xs font-bold text-[var(--muted)]">
                              <Pencil size={12} /> Edit {chore.title}
                            </summary>
                            <form
                              action={updateChore.bind(null, chore.id)}
                              className="mt-2 space-y-2 rounded-xl border border-[var(--line)] bg-white/50 p-3"
                            >
                              <input
                                name="title"
                                className="hub-input"
                                defaultValue={chore.title}
                                aria-label="Chore title"
                                required
                              />
                              <select
                                name="profileId"
                                className="hub-input"
                                defaultValue={chore.profileId ?? ""}
                                aria-label="Assign chore to"
                              >
                                <option value="">Whole family</option>
                                {familyProfiles.map((profile) => (
                                  <option value={profile.id} key={profile.id}>
                                    {profile.name}
                                  </option>
                                ))}
                              </select>
                              <select
                                name="cadence"
                                className="hub-input"
                                defaultValue={chore.cadence}
                                aria-label="Chore frequency"
                              >
                                <option value="daily">Every day</option>
                                <option value="weekly">Once a week</option>
                              </select>
                              <button className="hub-button w-full">
                                Save chore
                              </button>
                            </form>
                          </details>
                        </div>
                      );
                    })
                  ) : (
                    <p className="rounded-2xl border border-dashed border-[var(--line)] p-5 text-center text-sm text-[var(--muted)]">
                      Assign shared chores here.
                    </p>
                  )}
                </div>
              </section>
            );
          })}
        </div>
        <aside className="hub-card h-fit p-5 max-md:p-4">
          <div className="flex items-center gap-2">
            <Plus size={20} className="text-[var(--sage)]" />
            <h2 className="font-display text-2xl font-semibold">Add a chore</h2>
          </div>
          <form action={addChore} className="mt-5 space-y-3">
            <input
              name="title"
              className="hub-input"
              placeholder="Feed the dog"
              required
            />
            <select name="profileId" className="hub-input">
              <option value="">Whole family</option>
              {familyProfiles.map((profile) => (
                <option value={profile.id} key={profile.id}>
                  {profile.name}
                </option>
              ))}
            </select>
            <select name="cadence" className="hub-input" defaultValue="daily">
              <option value="daily">Every day</option>
              <option value="weekly">Once a week</option>
            </select>
            <button className="hub-button w-full">Add chore</button>
          </form>
        </aside>
      </div>
    </div>
  );
}
