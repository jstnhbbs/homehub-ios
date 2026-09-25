import { describe, expect, it } from "vitest";
import {
  colorForBirthdayName,
  combineBirthdaySources,
  listHouseholdBirthdays,
  nextBirthdayOccurrence,
} from "./family-birthdays";

const jamie = {
  id: "profile-1",
  name: "Jamie",
  color: "#d87861",
  avatar: "sparkles",
  birthday: "2020-07-18",
};

describe("family birthdays", () => {
  it("rolls a passed birthday into next year and computes the age they turn", () => {
    expect(nextBirthdayOccurrence("2020-07-18", "2026-07-19")).toEqual({
      localDate: "2027-07-18",
      daysUntil: 364,
      upcomingAge: 7,
    });
  });

  it("keeps today's birthday on this year", () => {
    expect(nextBirthdayOccurrence("2020-07-18", "2026-07-18")).toMatchObject({
      localDate: "2026-07-18",
      daysUntil: 0,
      upcomingAge: 6,
    });
  });

  it("picks a stable palette color from a name", () => {
    expect(colorForBirthdayName("Grandma Eve")).toBe(colorForBirthdayName("Grandma Eve"));
    expect(colorForBirthdayName("Grandma Eve")).not.toBe(colorForBirthdayName("Riley"));
  });

  it("prefers a household profile over a linked extra row", () => {
    const items = combineBirthdaySources(
      [jamie],
      [
        {
          id: "family-1",
          profileId: "profile-1",
          name: "Jamie duplicate",
          birthDate: "2019-01-01",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
        {
          id: "family-2",
          profileId: null,
          name: "Grandma Eve",
          birthDate: "1948-08-20",
          notes: null,
          giftIdeas: "Tea towels",
          notifyDaysBefore: 14,
        },
      ],
    );

    expect(items.map((item) => item.id)).toEqual(["profile-1", "family-2"]);
    expect(items[1]?.giftIdeas).toBe("Tea towels");
  });

  it("sorts the household list by days until the next birthday", () => {
    const items = listHouseholdBirthdays(
      [jamie],
      [
        {
          id: "family-2",
          profileId: null,
          name: "Grandma Eve",
          birthDate: "1948-08-20",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
      ],
      "2026-07-15",
    );

    expect(items.map((item) => item.name)).toEqual(["Jamie", "Grandma Eve"]);
    expect(items[0]).toMatchObject({ daysUntil: 3, source: "profile" });
    expect(items[1]?.daysUntil).toBeGreaterThan(3);
  });

  it("marks profile birthdays and rows without a kind as birthdays", () => {
    const items = combineBirthdaySources(
      [jamie],
      [
        {
          id: "family-1",
          profileId: null,
          name: "Grandma Eve",
          birthDate: "1948-08-20",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
      ],
    );
    expect(items.map((item) => item.kind)).toEqual(["birthday", "birthday"]);
  });

  it("carries an anniversary through and counts its years", () => {
    const items = listHouseholdBirthdays(
      [],
      [
        {
          id: "family-3",
          profileId: null,
          name: "Alex & Sam",
          birthDate: "2016-09-25",
          kind: "anniversary",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
      ],
      "2026-09-25",
    );
    expect(items[0]).toMatchObject({ kind: "anniversary", daysUntil: 0, upcomingAge: 10, source: "family" });
  });

  it("does not let a profile's birthday hide an anniversary linked to that profile", () => {
    const items = combineBirthdaySources(
      [jamie],
      [
        {
          id: "family-4",
          profileId: "profile-1",
          name: "Jamie's anniversary",
          birthDate: "2015-06-01",
          kind: "anniversary",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
        {
          id: "family-5",
          profileId: "profile-1",
          name: "Jamie duplicate",
          birthDate: "2019-01-01",
          kind: "birthday",
          notes: null,
          giftIdeas: null,
          notifyDaysBefore: 7,
        },
      ],
    );
    expect(items.map((item) => item.id)).toEqual(["profile-1", "family-4"]);
  });
});
