import { describe, expect, it } from "vitest";
import {
  extractJsonLdBlocks,
  formatDuration,
  parseRecipeFromHtml,
  stripHtml,
} from "./parse";

const sampleHtml = `
<!doctype html>
<html>
  <body>
    <article>
      <p>Lorem ipsum ads and fluff that should not be imported.</p>
    </article>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@graph": [
          {
            "@type": "WebPage",
            "name": "Ignore me"
          },
          {
            "@type": "Recipe",
            "name": "Weeknight Tacos",
            "description": "<p>Fast tacos for busy families.</p>",
            "recipeYield": "4 servings",
            "prepTime": "PT15M",
            "cookTime": "PT20M",
            "totalTime": "PT35M",
            "recipeIngredient": [
              "1 lb ground beef",
              "8 small tortillas",
              "1 cup shredded lettuce"
            ],
            "recipeInstructions": [
              {
                "@type": "HowToStep",
                "text": "Brown the beef in a skillet."
              },
              {
                "@type": "HowToStep",
                "text": "Warm the tortillas and assemble tacos."
              }
            ],
            "nutrition": {
              "@type": "NutritionInformation",
              "calories": "420 calories",
              "proteinContent": "24 g",
              "fatContent": "18 g"
            },
            "image": "https://example.com/tacos.jpg"
          }
        ]
      }
    </script>
  </body>
</html>
`;

describe("recipe parsing", () => {
  it("strips html from recipe text", () => {
    expect(stripHtml("<p>Hello <strong>world</strong></p>")).toBe("Hello world");
  });

  it("formats ISO durations for display", () => {
    expect(formatDuration("PT15M")).toBe("15 min");
    expect(formatDuration("PT1H30M")).toBe("1 hr 30 min");
  });

  it("extracts essentials from JSON-LD recipe blocks", () => {
    const blocks = extractJsonLdBlocks(sampleHtml);
    expect(blocks).toHaveLength(1);

    const recipe = parseRecipeFromHtml(sampleHtml, "https://example.com/tacos");
    expect(recipe).toMatchObject({
      title: "Weeknight Tacos",
      description: "Fast tacos for busy families.",
      servings: "4 servings",
      prepTime: "15 min",
      cookTime: "20 min",
      totalTime: "35 min",
      sourceUrl: "https://example.com/tacos",
      imageUrl: "https://example.com/tacos.jpg",
    });
    expect(recipe?.ingredients).toEqual([
      "1 lb ground beef",
      "8 small tortillas",
      "1 cup shredded lettuce",
    ]);
    expect(recipe?.directions).toEqual([
      "Brown the beef in a skillet.",
      "Warm the tortillas and assemble tacos.",
    ]);
    expect(recipe?.nutrition).toMatchObject({
      Calories: "420 calories",
      Protein: "24 g",
      Fat: "18 g",
    });
  });
});
