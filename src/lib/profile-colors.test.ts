import { describe, expect, it } from "vitest";
import { GUEST_PROFILE_COLOR, PROFILE_COLORS, PROFILE_COLOR_CHOICES, isProfileColor, pickProfileColor } from "./profile-colors";

const all = PROFILE_COLORS.map((color) => color.value);

describe("picking a color for a new profile", () => {
  it("starts with the first color when nobody has one", () => {
    expect(pickProfileColor([])).toBe(all[0]);
  });

  it("skips colors that are taken", () => {
    expect(pickProfileColor([all[0]])).toBe(all[1]);
    expect(pickProfileColor([all[0], all[1], all[3]])).toBe(all[2]);
  });

  it("fills a gap left by a profile that was removed or recolored", () => {
    expect(pickProfileColor([all[1], all[2]])).toBe(all[0]);
  });

  it("ignores case, empty values and colors outside the palette", () => {
    expect(pickProfileColor([all[0].toUpperCase(), null, undefined, "#123456"])).toBe(all[1]);
  });

  it("spreads repeats once every color is taken", () => {
    expect(pickProfileColor(all)).toBe(all[0]);
    expect(pickProfileColor([...all, all[0]])).toBe(all[1]);
    expect(pickProfileColor([...all, ...all.slice(0, 8)])).toBe(all[8]);
  });
});

describe("the guest grey", () => {
  it("can be chosen, but is not one of the nine family colors", () => {
    expect(isProfileColor(GUEST_PROFILE_COLOR.value)).toBe(true);
    expect(PROFILE_COLORS.map((color) => color.value)).not.toContain(GUEST_PROFILE_COLOR.value);
    expect(PROFILE_COLOR_CHOICES).toHaveLength(PROFILE_COLORS.length + 1);
    expect(isProfileColor("#123456")).toBe(false);
  });

  it("never counts as, or is handed out as, a family color", () => {
    expect(pickProfileColor([GUEST_PROFILE_COLOR.value])).toBe(all[0]);
    expect(pickProfileColor(all)).not.toBe(GUEST_PROFILE_COLOR.value);
  });
});
