import { and, eq } from "drizzle-orm";
import { formatInTimeZone } from "date-fns-tz";
import { Cookie, RotateCcw } from "lucide-react";
import { resetSnackChecklist, saveSnackOptions, toggleSnack } from "@/app/actions";
import { CheckItem } from "@/components/check-item";
import { db } from "@/db/client";
import { snackCompletions } from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import { parseSnackOptions, sortSnackOptions } from "@/lib/meals/snacks";

export default async function SnacksPage() {
  const household = await requireHousehold();
  const localDate = localDateIn(household.timezone);
  const snackOptions = parseSnackOptions(household.snackOptions);
  const completions = await db
    .select({ snackLabel: snackCompletions.snackLabel })
    .from(snackCompletions)
    .where(
      and(
        eq(snackCompletions.householdId, household.id),
        eq(snackCompletions.localDate, localDate),
      ),
    );
  const eaten = new Set(completions.map((item) => item.snackLabel));
  const snackItems = sortSnackOptions(snackOptions, eaten);
  const canManage = canManageHousehold(household.role);
  const dateLabel = formatInTimeZone(
    new Date(`${localDate}T12:00:00`),
    household.timezone,
    "EEEE, MMMM d",
  );

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Grab and go
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Today&apos;s snacks
          </h1>
          <p className="mt-2 text-sm font-bold text-[var(--muted)]">{dateLabel}</p>
        </div>
        {snackItems.length > 0 && (
          <form action={resetSnackChecklist}>
            <input type="hidden" name="localDate" value={localDate} />
            <button className="hub-button secondary">
              <RotateCcw size={16} /> Reset checklist
            </button>
          </form>
        )}
      </div>

      <div className="mt-6 grid grid-cols-[1fr_330px] gap-6 max-md:grid-cols-1 max-md:gap-4">
        <section className="hub-card p-5 max-md:p-4">
          <div className="flex items-center gap-2">
            <Cookie size={20} className="text-[var(--sage)]" />
            <h2 className="font-display text-2xl font-semibold">Snack checklist</h2>
          </div>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            Check off snacks as they&apos;re eaten. Checked items stay on the list
            with a strikethrough, and the checklist starts fresh every morning.
          </p>
          <div className="mt-5 space-y-2">
            {snackItems.length ? (
              snackItems.map((item) => (
                <CheckItem
                  key={item}
                  label={item}
                  initialChecked={eaten.has(item)}
                  onToggle={toggleSnack.bind(null, localDate, item)}
                />
              ))
            ) : (
              <p className="rounded-2xl border border-dashed border-[var(--line)] p-8 text-center text-sm text-[var(--muted)]">
                {canManage
                  ? "Add snack options in the panel to the right."
                  : "No snacks listed yet."}
              </p>
            )}
          </div>
          {snackItems.length > 0 && (
            <p className="mt-4 text-center text-sm font-bold text-[var(--muted)]">
              {eaten.size} of {snackItems.length} eaten today
            </p>
          )}
        </section>

        {canManage && (
          <aside className="hub-card h-fit p-5 max-md:p-4">
            <h2 className="font-display text-2xl font-semibold">Snack options</h2>
            <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
              Keep a running list of snacks the family can grab anytime.
            </p>
            <form action={saveSnackOptions} className="mt-5">
              <label className="block">
                <span className="sr-only">Snack options</span>
                <textarea
                  name="snackOptions"
                  defaultValue={household.snackOptions}
                  placeholder={"Apples\nYogurt tubes\nCheese sticks\nGranola bars"}
                  className="hub-input min-h-48 w-full resize-none leading-6"
                  aria-label="Snack options"
                />
              </label>
              <p className="mt-2 text-xs leading-5 text-[var(--muted)]">
                Put each snack on a new line, like routine steps.
              </p>
              <button className="hub-button mt-4 w-full">Save snack list</button>
            </form>
          </aside>
        )}
      </div>
    </div>
  );
}
