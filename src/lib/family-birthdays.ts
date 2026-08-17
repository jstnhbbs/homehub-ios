import { differenceInCalendarDays, parseISO } from "date-fns";
import { birthdayDateInYear } from "@/lib/birthdays";

export type BirthdayLike = {
  id: string;
  name: string;
  birthDate: string;
  color?: string;
  notes?: string | null;
  giftIdeas?: string | null;
  notifyDaysBefore?: number;
};

export function upcomingFamilyBirthdays(
  birthdays: BirthdayLike[],
  today: string,
  withinDays = 45,
) {
  const year = Number(today.slice(0, 4));
  return birthdays
    .flatMap((birthday) => {
      let localDate = birthdayDateInYear(birthday.birthDate, year);
      if (localDate < today) {
        localDate = birthdayDateInYear(birthday.birthDate, year + 1);
      }
      const daysUntil = differenceInCalendarDays(
        parseISO(localDate),
        parseISO(today),
      );
      return daysUntil <= withinDays ? [{ ...birthday, localDate, daysUntil }] : [];
    })
    .sort((a, b) => a.daysUntil - b.daysUntil);
}
