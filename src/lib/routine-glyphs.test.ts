import { describe, expect, it } from "vitest";
import { routineStepDisplay } from "./routine-glyphs";

describe("routineStepDisplay", () => {
  it("uses an explicit leading emoji as the glyph", () => {
    expect(routineStepDisplay("🪥 Brush teeth")).toEqual({
      glyph: "🪥",
      label: "Brush teeth",
    });
  });

  it("suggests a glyph from the step label", () => {
    expect(routineStepDisplay("Feed the dog")).toEqual({
      glyph: "🐶",
      label: "Feed the dog",
    });
  });

  it("suggests bedtime routine glyphs", () => {
    expect(routineStepDisplay("Change diaper").glyph).toBe("🍼");
    expect(routineStepDisplay("Sing a song").glyph).toBe("🎵");
    expect(routineStepDisplay("Say prayers").glyph).toBe("🙏");
  });

  it("falls back to a star for unknown labels", () => {
    expect(routineStepDisplay("Check the thing")).toEqual({
      glyph: "⭐",
      label: "Check the thing",
    });
  });
});
