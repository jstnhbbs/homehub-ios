import { describe, expect, it } from "vitest";
import { PROFILE_COLORS, pickProfileColor } from "./profile-colors";

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
