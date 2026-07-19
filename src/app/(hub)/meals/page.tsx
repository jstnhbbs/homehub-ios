import { and, asc, eq, gte, lte } from "drizzle-orm";
import { format } from "date-fns";
import { Copy, Trash2 } from "lucide-react";
import {
  clearMealWeek,
  copyPreviousMealWeek,
} from "@/app/actions";
import { MealInput } from "@/components/meal-input";
import { db } from "@/db/client";
import { meals, recipes } from "@/db/schema";
import { weekDates } from "@/lib/dates";
import { parseWeekStartsOn } from "@/lib/calendar/week-start";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";

const mealSlots = ["breakfast", "lunch", "dinner"] as const;

export default async function MealsPage() {
  const household = await requireHousehold();
  const days = weekDates(new Date(), parseWeekStartsOn(household.weekStartsOn));
  const dateStrings = days.map((day) => format(day, "yyyy-MM-dd"));
  const [weekMeals, householdRecipes] = await Promise.all([
    db
      .select()
      .from(meals)
      .where(
        and(
          eq(meals.householdId, household.id),
          gte(meals.localDate, dateStrings[0]),
          lte(meals.localDate, dateStrings[6]),
        ),
      ),
    db
      .select({ id: recipes.id, title: recipes.title })
      .from(recipes)
      .where(eq(recipes.householdId, household.id))
      .orderBy(asc(recipes.title)),
  ]);
  const weekStart = dateStrings[0];
  const canManage = canManageHousehold(household.role);

  return (
    <div className="mx-auto max-w-[1500px]">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            What’s cooking?
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Weekly meals
          </h1>
        </div>
        {canManage && (
          <div className="flex flex-wrap gap-2">
            <form action={copyPreviousMealWeek}>
              <input type="hidden" name="weekStart" value={weekStart} />
              <button className="hub-button secondary">
                <Copy size={16} /> Copy last week
              </button>
            </form>
            <form action={clearMealWeek}>
              <input type="hidden" name="weekStart" value={weekStart} />
              <button className="hub-button secondary text-[var(--coral)]">
                <Trash2 size={16} /> Clear week
              </button>
            </form>
          </div>
        )}
      </div>

      <div className="mt-6">
        <div className="min-w-0 space-y-4">
          <div className="space-y-3 lg:hidden">
            {days.map((day, dayIndex) => {
              const localDate = dateStrings[dayIndex];
              return (
                <section key={localDate} className="hub-card p-4">
                  <div className="mb-3 flex items-baseline justify-between">
                    <h2 className="font-display text-2xl font-semibold">
                      {format(day, "EEEE")}
                    </h2>
                    <span className="text-sm font-bold text-[var(--muted)]">
                      {format(day, "MMM d")}
                    </span>
                  </div>
                  <div className="space-y-4">
                    {mealSlots.map((slot) => {
                      const meal = weekMeals.find(
                        (item) =>
                          item.localDate === localDate && item.slot === slot,
                      );
                      return (
                        <div key={slot}>
                          <p className="mb-1 text-[10px] font-extrabold uppercase tracking-[0.14em] text-[var(--muted)]">
                            {slot}
                          </p>
                          <MealInput
                            key={`${localDate}-${slot}-${meal?.recipeId ?? ""}-${meal?.title ?? ""}`}
                            localDate={localDate}
                            slot={slot}
                            initialValue={meal?.title ?? ""}
                            initialRecipeId={meal?.recipeId}
                            recipes={householdRecipes}
                            readOnly={!canManage}
                          />
                        </div>
                      );
                    })}
                  </div>
                </section>
              );
            })}
          </div>

          <section className="hub-card overflow-hidden max-lg:hidden">
            <div className="grid grid-cols-[100px_repeat(7,minmax(120px,1fr))]">
              <div className="border-b border-r border-[var(--line)] p-3" />
              {days.map((day) => (
                <div
                  key={day.toISOString()}
                  className="border-b border-r border-[var(--line)] p-3 text-center last:border-r-0"
                >
                  <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
                    {format(day, "EEE")}
                  </p>
                  <p className="font-display mt-1 text-2xl font-semibold">
                    {format(day, "d")}
                  </p>
                </div>
              ))}
              {mealSlots.map((slot) => (
                <div key={slot} className="contents">
                  <div className="flex items-start border-b border-r border-[var(--line)] p-3 pt-5 text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
                    {slot}
                  </div>
                  {dateStrings.map((localDate) => {
                    const meal = weekMeals.find(
                      (item) =>
                        item.localDate === localDate && item.slot === slot,
                    );
                    return (
                      <div
                        key={`${localDate}-${slot}`}
                        className="min-h-36 border-b border-r border-[var(--line)] p-2 last:border-r-0"
                      >
                        <MealInput
                          key={`${localDate}-${slot}-${meal?.recipeId ?? ""}-${meal?.title ?? ""}`}
                          localDate={localDate}
                          slot={slot}
                          initialValue={meal?.title ?? ""}
                          initialRecipeId={meal?.recipeId}
                          recipes={householdRecipes}
                          readOnly={!canManage}
                        />
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
          </section>

          <p className="text-center text-sm text-[var(--muted)] max-lg:hidden">
            Pick a saved recipe or type a meal name. Put each item on its own
            line to add sides. Leave it blank to clear that slot.
          </p>
        </div>
      </div>
    </div>
  );
}
