import { addDays, format } from "date-fns";
import { formatInTimeZone, fromZonedTime } from "date-fns-tz";
import { z } from "zod";

export const calendarEventFormSchema = z.object({
  calendarId: z.string().uuid(),
  title: z.string().trim().min(1).max(150),
  startsAt: z.string().min(1),
  endsAt: z.string().min(1),
  allDay: z.boolean(),
  location: z.string().trim().max(200).optional(),
  description: z.string().trim().max(2000).optional(),
});

export type CalendarEventFormValues = z.infer<typeof calendarEventFormSchema>;

export function parseCalendarEventForm(formData: FormData) {
  return calendarEventFormSchema.parse({
    calendarId: formData.get("calendarId"),
    title: formData.get("title"),
    startsAt: formData.get("startsAt"),
    endsAt: formData.get("endsAt"),
    allDay: formData.get("allDay") === "on",
    location: formData.get("location")?.toString().trim() || undefined,
    description: formData.get("description")?.toString().trim() || undefined,
  });
}

export function eventTimesFromForm(
  input: CalendarEventFormValues,
  timezone: string,
) {
  if (input.allDay) {
    const startsAt = fromZonedTime(`${input.startsAt}T00:00:00`, timezone);
    let endsAt = fromZonedTime(`${input.endsAt}T00:00:00`, timezone);
    if (endsAt <= startsAt) {
      endsAt = addDays(startsAt, 1);
    }
    return { startsAt, endsAt, allDay: true as const };
  }
  const startsAt = fromZonedTime(input.startsAt, timezone);
  const endsAt = fromZonedTime(input.endsAt, timezone);
  if (endsAt <= startsAt) {
    throw new Error("Event end must be after its start.");
  }
  return { startsAt, endsAt, allDay: false as const };
}

export function defaultEventFieldValues(
  timezone: string,
  startsAt: Date,
  endsAt: Date,
  allDay: boolean,
) {
  if (allDay) {
    const inclusiveEnd =
      endsAt.getTime() - startsAt.getTime() <= 86_400_000
        ? startsAt
        : addDays(endsAt, -1);
    return {
      startsAt: format(startsAt, "yyyy-MM-dd"),
      endsAt: format(inclusiveEnd, "yyyy-MM-dd"),
    };
  }
  return {
    startsAt: formatInTimeZone(startsAt, timezone, "yyyy-MM-dd'T'HH:mm"),
    endsAt: formatInTimeZone(endsAt, timezone, "yyyy-MM-dd'T'HH:mm"),
  };
}
