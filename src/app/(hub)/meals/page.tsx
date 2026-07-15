import { and, eq, gte, lte } from "drizzle-orm";
import { format } from "date-fns";
import { Copy, Trash2 } from "lucide-react";
import {
  clearMealWeek,
  copyPreviousMealWeek,
} from "@/app/actions";
import { MealInput } from "@/components/meal-input";
import { db } from "@/db/client";
import { meals } from "@/db/schema";
import { weekDates } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";

const slots = ["breakfast", "lunch", "dinner", "snack"] as const;

export default async function MealsPage() {
  const household = await requireHousehold();
  const days = weekDates();
  const dateStrings = days.map((day) => format(day, "yyyy-MM-dd"));
  const weekMeals = await db
    .select()
    .from(meals)
    .where(
      and(
        eq(meals.householdId, household.id),
        gte(meals.localDate, dateStrings[0]),
        lte(meals.localDate, dateStrings[6]),
      ),
    );
  const weekStart = dateStrings[0];

  return (
    <div className="mx-auto max-w-[1500px]">
      <div className="flex items-end justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            What’s cooking?
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold">
            Weekly meals
          </h1>
        </div>
        <div className="flex gap-2">
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
      </div>

      <section className="hub-card mt-6 overflow-hidden">
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
          {slots.map((slot) => (
            <div key={slot} className="contents">
              <div className="flex items-center border-b border-r border-[var(--line)] p-3 text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
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
                    className="min-h-20 border-b border-r border-[var(--line)] p-2 last:border-r-0"
                  >
                    <MealInput
                      localDate={localDate}
                      slot={slot}
                      initialValue={meal?.title ?? ""}
                    />
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      </section>
      <p className="mt-4 text-center text-sm text-[var(--muted)]">
        Tap any meal to edit it. Leave it blank to clear that slot.
      </p>
    </div>
  );
}
