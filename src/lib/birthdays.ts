import { differenceInCalendarDays, parseISO } from "date-fns";
import { fromZonedTime } from "date-fns-tz";

type BirthdayProfile = {
  id: string;
  name: string;
  color: string;
  birthday: string | null;
  /** Defaults to a birthday. */
  kind?: "birthday" | "anniversary";
};

export function birthdayDateInYear(birthday: string, year: number) {
  const monthDay = birthday.slice(5);
  const date = `${year}-${monthDay}`;
  const parsed = parseISO(date);

  if (
    parsed.getFullYear() === year &&
    parsed.getMonth() + 1 === Number(monthDay.slice(0, 2)) &&
    parsed.getDate() === Number(monthDay.slice(3, 5))
  ) {
    return date;
  }

  return `${year}-02-28`;
}

export function birthdayEventsInRange(
  profiles: BirthdayProfile[],
  firstDate: string,
  lastDate: string,
  timezone: string,
) {
  const events = [];
  const firstYear = Number(firstDate.slice(0, 4));
  const lastYear = Number(lastDate.slice(0, 4));

  for (const profile of profiles) {
    if (!profile.birthday) continue;

    for (let year = firstYear; year <= lastYear; year += 1) {
      const localDate = birthdayDateInYear(profile.birthday, year);
      if (localDate < firstDate || localDate > lastDate) continue;

      const nextDate = new Date(`${localDate}T12:00:00Z`);
      nextDate.setUTCDate(nextDate.getUTCDate() + 1);
      const nextLocalDate = nextDate.toISOString().slice(0, 10);

      events.push({
        title: `${profile.name}’s ${profile.kind === "anniversary" ? "anniversary" : "birthday"}`,
        description: null,
        location: null,
        startsAt: fromZonedTime(`${localDate}T00:00:00`, timezone),
        endsAt: fromZonedTime(`${nextLocalDate}T00:00:00`, timezone),
        allDay: true,
        recurrenceRule: "YEARLY",
        eventId: `birthday-${profile.id}-${year}`,
        calendarId: "",
        color: profile.color,
        calendarName: profile.kind === "anniversary" ? "Family anniversaries" : "Family birthdays",
        isBirthday: true as const,
        profileId: profile.id,
      });
    }
  }

  return events;
}

export function upcomingBirthdays(
  profiles: BirthdayProfile[],
  today: string,
  withinDays = 14,
) {
  const year = Number(today.slice(0, 4));

  return profiles
    .flatMap((profile) => {
      if (!profile.birthday) return [];

      let localDate = birthdayDateInYear(profile.birthday, year);
      if (localDate < today) {
        localDate = birthdayDateInYear(profile.birthday, year + 1);
      }
      const daysUntil = differenceInCalendarDays(
        parseISO(localDate),
        parseISO(today),
      );

      return daysUntil <= withinDays
        ? [{ profile, localDate, daysUntil }]
        : [];
    })
    .sort((a, b) => a.daysUntil - b.daysUntil);
}
