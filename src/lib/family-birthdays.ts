import { differenceInCalendarDays, parseISO } from "date-fns";
import { birthdayDateInYear } from "@/lib/birthdays";
import { PROFILE_COLORS } from "@/lib/profile-colors";

export type BirthdaySource = "profile" | "family";

/** Birthdays and anniversaries are counted the same way; only the wording differs. */
export type CelebrationKind = "birthday" | "anniversary";

export type BirthdayLike = {
  id: string;
  name: string;
  birthDate: string;
  color?: string;
  notes?: string | null;
  giftIdeas?: string | null;
  notifyDaysBefore?: number;
};

export type BirthdayProfileSource = {
  id: string;
  name: string;
  color: string;
  avatar: string | null;
  birthday: string | null;
};

export type BirthdayFamilySource = {
  id: string;
  profileId: string | null;
  name: string;
  birthDate: string;
  /** Defaults to a birthday when missing. */
  kind?: CelebrationKind;
  notes: string | null;
  giftIdeas: string | null;
  notifyDaysBefore: number;
};

export type BirthdayItem = {
  id: string;
  source: BirthdaySource;
  kind: CelebrationKind;
  profileId: string | null;
  name: string;
  birthDate: string;
  color: string;
  avatar: string | null;
  notes: string | null;
  giftIdeas: string | null;
  notifyDaysBefore: number;
  nextDate: string;
  daysUntil: number;
  /** The age they turn, or for an anniversary the number of years it marks. */
  upcomingAge: number;
};

export function colorForBirthdayName(name: string) {
  const sum = [...name].reduce((total, character) => total + character.charCodeAt(0), 0);
  return PROFILE_COLORS[sum % PROFILE_COLORS.length].value;
}

export function nextBirthdayOccurrence(birthDate: string, today: string) {
  const year = Number(today.slice(0, 4));
  let localDate = birthdayDateInYear(birthDate, year);
  if (localDate < today) {
    localDate = birthdayDateInYear(birthDate, year + 1);
  }
  const daysUntil = differenceInCalendarDays(
    parseISO(localDate),
    parseISO(today),
  );
  const upcomingAge = Number(localDate.slice(0, 4)) - Number(birthDate.slice(0, 4));
  return { localDate, daysUntil, upcomingAge };
}

export function upcomingFamilyBirthdays(
  birthdays: BirthdayLike[],
  today: string,
  withinDays = 45,
) {
  return birthdays
    .flatMap((birthday) => {
      const next = nextBirthdayOccurrence(birthday.birthDate, today);
      return next.daysUntil <= withinDays
        ? [{ ...birthday, localDate: next.localDate, daysUntil: next.daysUntil }]
        : [];
    })
    .sort((a, b) => a.daysUntil - b.daysUntil);
}

export function combineBirthdaySources(
  profiles: BirthdayProfileSource[],
  familyRows: BirthdayFamilySource[],
): Omit<BirthdayItem, "nextDate" | "daysUntil" | "upcomingAge">[] {
  const profileItems = profiles.flatMap((profile) => {
    if (!profile.birthday) return [];
    return [
      {
        id: profile.id,
        source: "profile" as const,
        kind: "birthday" as const,
        profileId: profile.id,
        name: profile.name,
        birthDate: profile.birthday,
        color: profile.color,
        avatar: profile.avatar,
        notes: null,
        giftIdeas: null,
        notifyDaysBefore: 7,
      },
    ];
  });

  const profileIdsWithBirthday = new Set(profileItems.map((item) => item.profileId));
  const familyItems = familyRows.flatMap((row) => {
    const kind = row.kind ?? "birthday";
    // A profile's own birthday wins over an extra birthday row linked to it. Anniversaries are
    // a different occasion, so a linked profile's birthday never hides them.
    if (kind === "birthday" && row.profileId && profileIdsWithBirthday.has(row.profileId)) {
      return [];
    }
    const linked = row.profileId
      ? profiles.find((profile) => profile.id === row.profileId)
      : undefined;
    return [
      {
        id: row.id,
        source: "family" as const,
        kind,
        profileId: row.profileId,
        name: row.name,
        birthDate: row.birthDate,
        color: linked?.color ?? colorForBirthdayName(row.name),
        avatar: linked?.avatar ?? null,
        notes: row.notes,
        giftIdeas: row.giftIdeas,
        notifyDaysBefore: row.notifyDaysBefore,
      },
    ];
  });

  return [...profileItems, ...familyItems];
}

export function decorateBirthdayItems(
  items: Omit<BirthdayItem, "nextDate" | "daysUntil" | "upcomingAge">[],
  today: string,
): BirthdayItem[] {
  return items
    .map((item) => {
      const next = nextBirthdayOccurrence(item.birthDate, today);
      return {
        ...item,
        nextDate: next.localDate,
        daysUntil: next.daysUntil,
        upcomingAge: next.upcomingAge,
      };
    })
    .sort((a, b) => a.daysUntil - b.daysUntil || a.name.localeCompare(b.name));
}

export function listHouseholdBirthdays(
  profiles: BirthdayProfileSource[],
  familyRows: BirthdayFamilySource[],
  today: string,
) {
  return decorateBirthdayItems(combineBirthdaySources(profiles, familyRows), today);
}
