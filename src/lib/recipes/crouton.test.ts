import { describe, expect, it } from "vitest";
import {
  croutonRecipeSchema,
  formatAmount,
  formatIngredient,
  mapCroutonRecipe,
  parseNutrition,
  type CroutonRecipe,
} from "@/lib/recipes/crouton";

type Ingredient = CroutonRecipe["ingredients"][number];

const ingredient = (name: string, quantity?: Ingredient["quantity"]): Ingredient => ({
  ingredient: { name },
  quantity,
});

/** The smallest valid export, with any field overridden. */
function recipe(overrides: Partial<CroutonRecipe> = {}): CroutonRecipe {
  return croutonRecipeSchema.parse({
    uuid: "ABC-123",
    name: "Test Soup",
    ingredients: [],
    steps: [],
    ...overrides,
  });
}

const steps = (...items: Array<string | [string, "section"]>) =>
  items.map((item, order) =>
    Array.isArray(item)
      ? { order, step: item[0], isSection: true }
      : { order, step: item, isSection: false },
  );

describe("formatAmount", () => {
  it.each([
    [1, "1"],
    [2, "2"],
    [0.5, "½"],
    [0.25, "¼"],
    [0.75, "¾"],
    [0.333, "⅓"],
    [1 / 3, "⅓"],
    [0.667, "⅔"],
    [0.125, "⅛"],
    [0.875, "⅞"],
    [1.5, "1 ½"],
    [2.75, "2 ¾"],
    [1.333, "1 ⅓"],
    [0.9999, "1"],
    [2.3, "2.3"],
    [0.1, "0.1"],
    [250, "250"],
  ])("%s -> %s", (amount, expected) => {
    expect(formatAmount(amount)).toBe(expected);
  });
});

describe("formatIngredient", () => {
  it.each([
    ["a count of whole items has no unit", ingredient("yellow onion, chopped", { quantityType: "ITEM", amount: 1 }), "1 yellow onion, chopped"],
    ["cups are plural above one", ingredient("flour", { quantityType: "CUP", amount: 2 }), "2 cups flour"],
    ["and singular at one", ingredient("flour", { quantityType: "CUP", amount: 1 }), "1 cup flour"],
    ["and singular below one", ingredient("flour", { quantityType: "CUP", amount: 0.5 }), "½ cup flour"],
    ["a mixed number", ingredient("carrots, chopped", { quantityType: "CUP", amount: 1.5 }), "1 ½ cups carrots, chopped"],
    ["tablespoons", ingredient("butter", { quantityType: "TABLESPOON", amount: 6 }), "6 tbsp butter"],
    ["teaspoons, never plural", ingredient("salt", { quantityType: "TEASPOON", amount: 0.5 }), "½ tsp salt"],
    ["ounces", ingredient("cream cheese", { quantityType: "OUNCE", amount: 8 }), "8 oz cream cheese"],
    ["pounds", ingredient("beef", { quantityType: "POUND", amount: 0.75 }), "¾ lb beef"],
    ["cans", ingredient("beans (15 oz)", { quantityType: "CAN", amount: 4 }), "4 cans beans (15 oz)"],
    ["a single can", ingredient("tomatoes", { quantityType: "CAN", amount: 1 }), "1 can tomatoes"],
    ["bunches", ingredient("cilantro", { quantityType: "BUNCH", amount: 2 }), "2 bunches cilantro"],
    ["a pinch", ingredient("red pepper flakes", { quantityType: "PINCH", amount: 1 }), "1 pinch red pepper flakes"],
    ["packets", ingredient("taco seasoning", { quantityType: "PACKET", amount: 2 }), "2 packets taco seasoning"],
    ["bottles", ingredient("beer", { quantityType: "BOTTLE", amount: 1 }), "1 bottle beer"],
    ["grams", ingredient("sourdough starter", { quantityType: "GRAMS", amount: 90 }), "90 g sourdough starter"],
    ["litres", ingredient("broth", { quantityType: "LITRES", amount: 1 }), "1 l broth"],
    ["millilitres, which Crouton calls MILLS", ingredient("orange juice", { quantityType: "MILLS", amount: 100 }), "100 ml orange juice"],
    ["decilitres become millilitres", ingredient("water", { quantityType: "DECILITER", amount: 3 }), "300 ml water"],
    ["a range, using the larger for the plural", ingredient("chicken broth", { quantityType: "CUP", amount: 5, secondaryAmount: 6 }), "5–6 cups chicken broth"],
    ["a range of tablespoons", ingredient("lime juice", { quantityType: "TABLESPOON", amount: 1, secondaryAmount: 2 }), "1–2 tbsp lime juice"],
    ["a range that starts below one", ingredient("sugar", { quantityType: "CUP", amount: 0.5, secondaryAmount: 2 }), "½–2 cups sugar"],
    ["a secondary amount that isn't larger is ignored", ingredient("sugar", { quantityType: "CUP", amount: 2, secondaryAmount: 2 }), "2 cups sugar"],
    ["no quantity at all", ingredient("kosher salt and black pepper"), "kosher salt and black pepper"],
    ["a quantity with no amount", ingredient("parsley", { quantityType: "CUP" }), "parsley"],
    ["a unit Crouton adds that we don't know, kept as words", ingredient("rum", { quantityType: "SPLASH", amount: 2 }), "2 splash rum"],
    ["messy whitespace", ingredient("  fresh   sage\n leaves ", { quantityType: "ITEM", amount: 8 }), "8 fresh sage leaves"],
  ])("%s", (_label, input, expected) => {
    expect(formatIngredient(input)).toBe(expected);
  });

  it("turns a SECTION row into a heading, without a trailing colon", () => {
    expect(formatIngredient(ingredient("Gravy", { quantityType: "SECTION" }))).toBe("## Gravy");
    expect(formatIngredient(ingredient("For the sauce:", { quantityType: "SECTION" }))).toBe("## For the sauce");
  });

  it("drops an ingredient with no name, and clips an enormous one", () => {
    expect(formatIngredient(ingredient("   ", { quantityType: "CUP", amount: 1 }))).toBeNull();
    const clipped = formatIngredient(ingredient("x".repeat(500), { quantityType: "CUP", amount: 1 }))!;
    expect(clipped.length).toBe(300);
    expect(clipped.endsWith("…")).toBe(true);
  });

  it("writes amounts the grocery list can read back", () => {
    // The unit spellings must be ones IngredientMerge recognises, or lists stop adding up.
    const known = ["cup", "cups", "tbsp", "tsp", "oz", "lb", "g", "ml", "l", "can", "cans", "bunch", "bunches", "pinch", "pinches", "packet", "packets"];
    const types = ["CUP", "TABLESPOON", "TEASPOON", "OUNCE", "POUND", "GRAMS", "MILLS", "LITRES", "CAN", "BUNCH", "PINCH", "PACKET"];
    for (const quantityType of types) {
      for (const amount of [1, 3]) {
        const line = formatIngredient(ingredient("thing", { quantityType, amount }))!;
        const unit = line.split(" ")[1];
        expect(known, `${quantityType} ${amount} -> ${line}`).toContain(unit);
      }
    }
  });
});

describe("parseNutrition", () => {
  it("reads 'Label: value' lines", () => {
    expect(parseNutrition("Fat: 31 g\nCalories: 489 kcal\nSodium: 2017 mg\nServing Size: 1 serving")).toEqual({
      Fat: "31 g",
      Calories: "489 kcal",
      Sodium: "2017 mg",
      "Serving Size": "1 serving",
    });
  });

  it("reads a trailing comma, as in 'Calories: 528 kcal,'", () => {
    expect(parseNutrition("Calories: 528 kcal,\nServing Size: 1 serving")).toEqual({
      Calories: "528 kcal",
      "Serving Size": "1 serving",
    });
  });

  it("reads a label followed by its amount, and keeps only the amount, not the daily-value percentage", () => {
    expect(parseNutrition("Total Fat 21g 26%\nSaturated Fat 11g 56%\nCholesterol 164mg 55%\nTotal Carbohydrate 50g 18%\nDietary Fiber 2g 9%\nTotal Sugars 24g\nProtein 12g")).toEqual({
      Fat: "21g",
      "Saturated Fat": "11g",
      Cholesterol: "164mg",
      Carbohydrates: "50g",
      Fiber: "2g",
      Sugar: "24g",
      Protein: "12g",
    });
  });

  it("copes with percentages in brackets, decimals and upper case", () => {
    expect(parseNutrition("Fat 32.4 g (49.9%)\nCALORIES 433KCAL\nVITAMIN C 56.2%\nSODIUM 1297mg")).toEqual({
      Fat: "32.4 g",
      Calories: "433KCAL",
      "Vitamin C": "56.2%",
      Sodium: "1297mg",
    });
  });

  it("reads a bare calorie count", () => {
    expect(parseNutrition("182 kcal")).toEqual({ Calories: "182 kcal" });
  });

  it("makes the common spellings one label, and the first value wins", () => {
    expect(parseNutrition("Carbs 38g\nCarbohydrates 99g\nSugars 12g")).toEqual({ Carbohydrates: "38g", Sugar: "12g" });
  });

  it("drops the page furniture copied along with the numbers", () => {
    expect(
      parseNutrition(
        "Nutrition Facts\nAmount per serving\n(per serving)\n% Daily Value*\nshellfish-free\nfish-free\n*The % Daily Value (DV) tells you how much a nutrient in a food serving contributes to a daily diet.\nCalories 430",
      ),
    ).toEqual({ Calories: "430" });
  });

  it("gives nothing when there is nothing to read", () => {
    expect(parseNutrition(undefined)).toBeUndefined();
    expect(parseNutrition("")).toBeUndefined();
    expect(parseNutrition("Nutrition Facts\nvegan")).toBeUndefined();
  });
});

describe("mapCroutonRecipe", () => {
  it("identifies the recipe by its Crouton id, lowercased so the same file always matches", () => {
    expect(mapCroutonRecipe(recipe({ uuid: "DB0AAC6C-F0F0-43AE" })).importKey).toBe("crouton:db0aac6c-f0f0-43ae");
  });

  it("maps times and servings", () => {
    const mapped = mapCroutonRecipe(recipe({ serves: 6, duration: 15, cookingDuration: 30 }));
    expect(mapped).toMatchObject({ servings: "6 servings", prepTime: "15 min", cookTime: "30 min", totalTime: "45 min" });
  });

  it("words one serving, long times and half measures properly", () => {
    expect(mapCroutonRecipe(recipe({ serves: 1 })).servings).toBe("1 serving");
    expect(mapCroutonRecipe(recipe({ serves: 2.5 })).servings).toBe("2.5 servings");
    const long = mapCroutonRecipe(recipe({ duration: 20, cookingDuration: 140 }));
    expect(long.cookTime).toBe("2 hrs 20 min");
    expect(long.totalTime).toBe("2 hrs 40 min");
    expect(mapCroutonRecipe(recipe({ cookingDuration: 60 })).cookTime).toBe("1 hr");
  });

  it("leaves out times and servings it wasn't given, and a total it can't work out", () => {
    const mapped = mapCroutonRecipe(recipe({ duration: 10 }));
    expect(mapped.prepTime).toBe("10 min");
    expect(mapped.cookTime).toBeUndefined();
    expect(mapped.totalTime).toBeUndefined();
    expect(mapped.servings).toBeUndefined();
    const zeros = mapCroutonRecipe(recipe({ serves: 0, duration: 0, cookingDuration: 0 }));
    expect(zeros).toMatchObject({ servings: undefined, prepTime: undefined, cookTime: undefined });
  });

  it("keeps the source link, but only when it is a web link", () => {
    expect(mapCroutonRecipe(recipe({ webLink: "https://example.com/soup" })).sourceUrl).toBe("https://example.com/soup");
    expect(mapCroutonRecipe(recipe({ webLink: "javascript:alert(1)" })).sourceUrl).toBeUndefined();
    expect(mapCroutonRecipe(recipe({ webLink: "file:///etc/passwd" })).sourceUrl).toBeUndefined();
    expect(mapCroutonRecipe(recipe({ webLink: "" })).sourceUrl).toBeUndefined();
  });

  it("notes where a recipe came from when there is no link, after the person's own notes", () => {
    expect(mapCroutonRecipe(recipe({ sourceName: "Simply Recipes" })).notes).toBe("Source: Simply Recipes");
    expect(mapCroutonRecipe(recipe({ sourceName: "Simply Recipes", notes: "Less salt." })).notes).toBe("Less salt.\n\nSource: Simply Recipes");
    // With a link, the name would only repeat it.
    expect(mapCroutonRecipe(recipe({ sourceName: "x.com", webLink: "https://x.com/a" })).notes).toBeUndefined();
    expect(mapCroutonRecipe(recipe({ notes: "  Keeps a week.  " })).notes).toBe("Keeps a week.");
  });

  it("clips a title and notes that are too long for the app", () => {
    expect(mapCroutonRecipe(recipe({ name: "x".repeat(400) })).title.length).toBe(200);
    expect(mapCroutonRecipe(recipe({ notes: "n".repeat(9000) })).notes!.length).toBe(4000);
  });

  describe("ingredients", () => {
    it("come out in Crouton's own order, not the file's", () => {
      const mapped = mapCroutonRecipe(
        recipe({
          ingredients: [
            { order: 2, ...ingredient("third") },
            { order: 0, ...ingredient("first") },
            { order: 1, ...ingredient("second") },
          ],
        }),
      );
      expect(mapped.ingredients).toEqual(["first", "second", "third"]);
    });

    it("keep group headings, and drop a heading with nothing under it", () => {
      const mapped = mapCroutonRecipe(
        recipe({
          ingredients: [
            ingredient("Sirloin Tips", { quantityType: "SECTION" }),
            ingredient("beef", { quantityType: "POUND", amount: 2 }),
            ingredient("Gravy", { quantityType: "SECTION" }),
            ingredient("Mash", { quantityType: "SECTION" }),
            ingredient("potatoes", { quantityType: "ITEM", amount: 3 }),
            ingredient("Garnish", { quantityType: "SECTION" }),
          ],
        }),
      );
      expect(mapped.ingredients).toEqual(["## Sirloin Tips", "2 lb beef", "## Mash", "3 potatoes"]);
    });
  });

  describe("directions", () => {
    it("drop the 'N.' numbering, since the app numbers steps itself", () => {
      const mapped = mapCroutonRecipe(recipe({ steps: steps("1. Chop the onion.", "2) Fry it.", "12. Serve.") }));
      expect(mapped.directions).toEqual(["Chop the onion.", "Fry it.", "Serve."]);
    });

    it("leave a step that merely starts with a quantity alone", () => {
      const mapped = mapCroutonRecipe(recipe({ steps: steps("2 jalapeno peppers diced", "1 poblano pepper diced", "3.5 oz of cheese") }));
      expect(mapped.directions).toEqual(["2 jalapeno peppers diced", "1 poblano pepper diced", "3.5 oz of cheese"]);
    });

    it("turn section rows into headings", () => {
      const mapped = mapCroutonRecipe(
        recipe({ steps: steps(["Crockpot", "section"], "1. Combine.", "2. Cook.", ["Stove:", "section"], "1. Simmer.") }),
      );
      expect(mapped.directions).toEqual(["## Crockpot", "Combine.", "Cook.", "## Stove", "Simmer."]);
    });

    it("split a numbered list that was squashed into one step", () => {
      const mapped = mapCroutonRecipe(
        recipe({
          steps: steps(
            "1. Bring to a boil.2. Remove the garlic and shred the chicken. 3. Add the butter.4. Ladle into bowls. Enjoy!",
          ),
        }),
      );
      expect(mapped.directions).toEqual([
        "Bring to a boil.",
        "Remove the garlic and shred the chicken.",
        "Add the butter.",
        "Ladle into bowls. Enjoy!",
      ]);
    });

    it("split only a run that counts up from 1 straight after sentence ends", () => {
      // A number in the middle of a sentence is not a step number, and a list must start at 1.
      expect(mapCroutonRecipe(recipe({ steps: steps("1. Cook for 2. Add the rest after 3. Done.") })).directions).toEqual([
        "Cook for 2. Add the rest after 3. Done.",
      ]);
      expect(mapCroutonRecipe(recipe({ steps: steps("Whisk. 2. Bake.") })).directions).toEqual(["Whisk. 2. Bake."]);
      // The run stops where the counting does.
      expect(mapCroutonRecipe(recipe({ steps: steps("1. Mix.2. Bake.4. Cool.") })).directions).toEqual(["Mix.", "Bake.4. Cool."]);
    });

    it("keep order, skip empty steps, and drop a trailing heading", () => {
      const mapped = mapCroutonRecipe(
        recipe({
          steps: [
            { order: 1, step: "Second.", isSection: false },
            { order: 0, step: "First.", isSection: false },
            { order: 2, step: "   ", isSection: false },
            { order: 3, step: "Notes", isSection: true },
          ],
        }),
      );
      expect(mapped.directions).toEqual(["First.", "Second."]);
    });

    it("clip a step that is longer than the app allows", () => {
      const long = mapCroutonRecipe(recipe({ steps: steps("x".repeat(4000)) })).directions[0];
      expect(long.length).toBe(3000);
    });
  });

  describe("tags", () => {
    it("keep the person's own, spelled the way the app spells them", () => {
      const mapped = mapCroutonRecipe(recipe({ tags: [{ name: "chicken" }, { name: "dinner party" }, { name: "Chicken" }] }));
      expect(mapped.tags).toEqual(["Chicken", "Dinner Party"]);
    });

    it("add the protein the ingredients show, after the person's own", () => {
      const mapped = mapCroutonRecipe(
        recipe({
          tags: [{ name: "Weeknight" }],
          ingredients: [ingredient("boneless chicken thighs", { quantityType: "POUND", amount: 2 })],
        }),
      );
      expect(mapped.tags).toEqual(["Weeknight", "Chicken"]);
    });

    it("do not read a protein out of a heading", () => {
      const mapped = mapCroutonRecipe(
        recipe({ ingredients: [ingredient("Chicken", { quantityType: "SECTION" }), ingredient("rice", { quantityType: "CUP", amount: 1 })] }),
      );
      expect(mapped.tags).toEqual([]);
    });
  });
});

describe("croutonRecipeSchema", () => {
  it("discards the embedded photos instead of carrying them", () => {
    const parsed = croutonRecipeSchema.parse({
      uuid: "u",
      name: "n",
      ingredients: [],
      steps: [],
      images: ["/9j/4AAQ".repeat(1000)],
      sourceImage: "/9j/4AAQ".repeat(100),
      rating: 5,
      folderIDs: ["x"],
    });
    expect(Object.keys(parsed).sort()).toEqual(["ingredients", "name", "steps", "uuid"]);
  });

  it("accepts nulls where Crouton leaves a field out", () => {
    expect(
      croutonRecipeSchema.safeParse({ uuid: "u", name: "n", ingredients: [{ ingredient: { name: "x" }, quantity: null }], steps: [], serves: null, webLink: null, tags: null }).success,
    ).toBe(true);
  });

  it.each([
    ["no id", { name: "n", ingredients: [], steps: [] }],
    ["no name", { uuid: "u", name: "  ", ingredients: [], steps: [] }],
    ["ingredients that aren't a list", { uuid: "u", name: "n", ingredients: "flour", steps: [] }],
    ["an absurd amount", { uuid: "u", name: "n", ingredients: [{ ingredient: { name: "x" }, quantity: { amount: 1e12, quantityType: "CUP" } }], steps: [] }],
    ["a negative serving count", { uuid: "u", name: "n", ingredients: [], steps: [], serves: -2 }],
    ["thousands of steps", { uuid: "u", name: "n", ingredients: [], steps: Array.from({ length: 400 }, (_, order) => ({ order, step: "x" })) }],
  ])("refuses %s", (_label, input) => {
    expect(croutonRecipeSchema.safeParse(input).success).toBe(false);
  });
});

describe("a recipe shaped like a real export", () => {
  const exported = {
    uuid: "8C2CB9D5-DFC4-4610-ACC8-0452B1DCEE04",
    name: "Cozy Soup",
    serves: 6,
    defaultScale: 2,
    duration: 15,
    cookingDuration: 30,
    rating: 0,
    isPublicRecipe: false,
    folderIDs: [],
    webLink: "https://example.com/cozy-soup/",
    sourceName: "example.com",
    neutritionalInfo: "Calories: 528 kcal,\nServing Size: 1 serving",
    tags: [{ uuid: "t1", color: "#FCBE56", name: "Chicken" }],
    ingredients: [
      { uuid: "i1", order: 0, ingredient: { uuid: "x1", name: "boneless skinless chicken breasts" }, quantity: { quantityType: "POUND", amount: 0.75 } },
      { uuid: "i2", order: 1, ingredient: { uuid: "x2", name: "yellow onion, chopped" }, quantity: { quantityType: "ITEM", amount: 1 } },
      { uuid: "i3", order: 2, ingredient: { uuid: "x3", name: "kosher salt and black pepper" } },
      { uuid: "i4", order: 3, ingredient: { uuid: "x4", name: "chicken broth" }, quantity: { quantityType: "CUP", amount: 5, secondaryAmount: 6 } },
    ],
    steps: [
      { uuid: "s0", order: 0, isSection: true, step: "Slow cooker" },
      { uuid: "s1", order: 1, isSection: false, step: "1. Combine everything." },
      { uuid: "s2", order: 2, isSection: false, step: "2. Cook on low 6 hours." },
    ],
    images: ["/9j/4AAQSkZJRgABAQ"],
    sourceImage: "/9j/4AAQSkZJRgABAQ",
  };

  it("becomes the recipe the app expects", () => {
    expect(mapCroutonRecipe(croutonRecipeSchema.parse(exported))).toEqual({
      importKey: "crouton:8c2cb9d5-dfc4-4610-acc8-0452b1dcee04",
      title: "Cozy Soup",
      servings: "6 servings",
      prepTime: "15 min",
      cookTime: "30 min",
      totalTime: "45 min",
      ingredients: [
        "¾ lb boneless skinless chicken breasts",
        "1 yellow onion, chopped",
        "kosher salt and black pepper",
        "5–6 cups chicken broth",
      ],
      directions: ["## Slow cooker", "Combine everything.", "Cook on low 6 hours."],
      nutrition: { Calories: "528 kcal", "Serving Size": "1 serving" },
      sourceUrl: "https://example.com/cozy-soup/",
      notes: undefined,
      tags: ["Chicken"],
    });
  });
});
