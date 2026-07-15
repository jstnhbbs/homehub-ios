import { fetchRecipeHtml } from "./fetch";
import { parseRecipeFromHtml } from "./parse";

export async function importRecipeFromUrl(url: string) {
  const html = await fetchRecipeHtml(url);
  const recipe = parseRecipeFromHtml(html, url);
  if (!recipe) {
    throw new Error(
      "Could not find structured recipe data on that page. Try adding it manually.",
    );
  }
  return recipe;
}
