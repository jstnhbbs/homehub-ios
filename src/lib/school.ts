import { addDays, parseISO } from "date-fns";

export const WEEKDAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

export function weekdayForLocalDate(localDate: string) {
  return parseISO(`${localDate}T12:00:00`).getDay();
}

export function nextSchoolDate(localDate: string) {
  let date = parseISO(`${localDate}T12:00:00`);
  for (let index = 0; index < 7; index += 1) {
    date = addDays(date, index === 0 ? 1 : 1);
    const weekday = date.getDay();
    if (weekday >= 1 && weekday <= 5) {
      return date.toISOString().slice(0, 10);
    }
  }
  return localDate;
}

export function parsePackItems(value: string) {
  return value
    .split("\n")
    .map((item) => item.trim())
    .filter(Boolean);
}
