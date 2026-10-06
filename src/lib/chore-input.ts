import { z } from "zod";
import { resolveChoreSchedule } from "@/lib/chores";

const weekday = z.enum(["0", "1", "2", "3", "4", "5", "6"]);

/**
 * What the app sends to add or change a chore. Apps that predate repeat rules send `cadence`
 * (daily or weekly), `weekDay` and `dueDate` only; newer ones send `repeatUnit` and the rest,
 * and still send `cadence` so an older server can read them.
 */
export const choreInputSchema = z
  .object({
    title: z.string().trim().min(1).max(120),
    profileId: z.string().uuid().optional(),
    cadence: z.enum(["daily", "weekly"]).optional(),
    repeatUnit: z.enum(["none", "day", "week", "month", "year"]).optional(),
    repeatInterval: z.number().int().min(1).max(99).optional(),
    weekDay: weekday.optional(),
    weekdays: z.array(weekday).max(7).optional(),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    dueTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  })
  .refine((input) => input.cadence || input.repeatUnit, {
    message: "Choose how often the chore repeats.",
    path: ["repeatUnit"],
  });

export type ChoreInput = z.infer<typeof choreInputSchema>;

/** The columns a chore row takes from the input. */
export function choreScheduleColumns(input: ChoreInput) {
  const schedule = resolveChoreSchedule(input);
  return {
    cadence: schedule.cadence,
    repeatUnit: schedule.repeatUnit,
    repeatInterval: schedule.repeatInterval,
    days: schedule.days,
    dueDate: schedule.dueDate,
    dueTime: schedule.dueTime,
  };
}
