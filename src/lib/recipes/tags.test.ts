import { describe, expect, it } from "vitest";
import { MAX_TAGS, MAX_TAG_LENGTH, mealTagForSlot, normalizeTags, suggestTags } from "./tags";

describe("normalizeTags", () => {
  it("fixes the casing of presets and title-cases custom tags", () => {
    expect(normalizeTags(["dinner", "CHICKEN", "slow cooker", "one-pot"])).toEqual([
      "Dinner",
      "Chicken",
      "Slow Cooker",
      "One-pot",
    ]);
  });

  it("trims, collapses spaces, and drops blanks", () => {
    expect(normalizeTags(["  Dinner  ", "", "   ", "air   fryer"])).toEqual(["Dinner", "Air Fryer"]);
  });

  it("drops duplicates regardless of case, keeping the first", () => {
    expect(normalizeTags(["Beef", "beef", "BEEF", "Pork"])).toEqual(["Beef", "Pork"]);
  });

  it("limits how long a tag is and how many a recipe can have", () => {
    const long = "a".repeat(MAX_TAG_LENGTH + 20);
    expect(normalizeTags([long])[0]).toHaveLength(MAX_TAG_LENGTH);
    const many = Array.from({ length: MAX_TAGS + 5 }, (_, i) => `tag ${i}`);
    expect(normalizeTags(many)).toHaveLength(MAX_TAGS);
  });

  it("keeps non-English letters", () => {
    expect(normalizeTags(["crème brûlée"])).toEqual(["Crème Brûlée"]);
  });
});

describe("suggestTags", () => {
  it("reads the meal type from the page's recipe category", () => {
    expect(suggestTags({ title: "X", ingredients: [], categories: ["Dinner"] })).toEqual(["Dinner"]);
    expect(suggestTags({ title: "X", ingredients: [], categories: ["Main Course", "Brunch"] })).toEqual([
      "Breakfast",
      "Dinner",
    ]);
    expect(suggestTags({ title: "X", ingredients: [], categories: ["Appetizer"] })).toEqual(["Snack"]);
  });

  it("finds proteins in the ingredients", () => {
    const tags = suggestTags({
      title: "Sheet pan dinner",
      ingredients: ["2 lb chicken thighs", "1 lb bacon", "1 tbsp olive oil"],
    });
    expect(tags).toEqual(["Chicken", "Pork"]);
  });

  it("does not call a vegetable soup chicken because of the broth", () => {
    const tags = suggestTags({
      title: "Vegetable soup",
      ingredients: ["4 cups chicken broth", "2 carrots", "1 onion", "1 tsp chicken bouillon"],
    });
    expect(tags).toEqual([]);
  });

  it("does not treat fish sauce as fish", () => {
    expect(suggestTags({ title: "Pad thai", ingredients: ["2 tbsp fish sauce", "8 oz rice noodles"] })).toEqual([]);
  });

  it("tags fish and shellfish separately", () => {
    expect(suggestTags({ title: "Salmon bowl", ingredients: ["1 lb salmon fillet"] })).toEqual(["Fish"]);
    expect(suggestTags({ title: "Scampi", ingredients: ["1 lb shrimp", "linguine"] })).toEqual(["Seafood"]);
  });

  it("matches whole words only", () => {
    expect(suggestTags({ title: "Hamburger buns", ingredients: ["1 cup flour", "shamrock sprinkles"] })).toEqual([]);
  });

  it("returns nothing when there is nothing to go on", () => {
    expect(suggestTags({ title: "Mystery", ingredients: [] })).toEqual([]);
  });

  it("checks the title as well as the ingredients", () => {
    expect(suggestTags({ title: "Beef stew", ingredients: ["2 carrots"] })).toEqual(["Beef"]);
  });
});

describe("mealTagForSlot", () => {
  it("maps planner slots to meal tags", () => {
    expect(mealTagForSlot("dinner")).toBe("Dinner");
    expect(mealTagForSlot("breakfast")).toBe("Breakfast");
    expect(mealTagForSlot("brunch")).toBeUndefined();
  });
});
