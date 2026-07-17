import { asc, eq } from "drizzle-orm";
import Link from "next/link";
import { Download, Plus } from "lucide-react";
import { addRecipe, importRecipe } from "./actions";
import { RecipeFields } from "@/components/recipe-fields";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import { recipeFromRow } from "@/lib/recipes/store";

export default async function RecipesPage() {
  const household = await requireHousehold();
  const rows = await db
    .select()
    .from(recipes)
    .where(eq(recipes.householdId, household.id))
    .orderBy(asc(recipes.title));
  const recipeList = rows.map(recipeFromRow);
  const canManage = canManageHousehold(household.role);

  return (
    <div className="mx-auto max-w-[1400px]">
      <div>
        <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
          Family favorites
        </p>
        <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
          Recipes
        </h1>
      </div>

      <div className="mt-6 grid grid-cols-[1fr_330px] gap-6 max-md:grid-cols-1 max-md:gap-4">
        <div className="grid auto-rows-min gap-4 sm:grid-cols-2">
          {recipeList.length ? (
            recipeList.map((recipe) => (
              <Link
                key={recipe.id}
                href={`/recipes/${recipe.id}`}
                className="hub-card overflow-hidden transition hover:-translate-y-0.5"
              >
                {recipe.imageUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={recipe.imageUrl}
                    alt=""
                    className="h-40 w-full object-cover"
                  />
                ) : (
                  <div className="flex h-40 items-center justify-center bg-[var(--sun-soft)]/60 text-sm font-bold text-[var(--muted)]">
                    No photo
                  </div>
                )}
                <div className="p-5">
                  <h2 className="font-display text-2xl font-semibold">
                    {recipe.title}
                  </h2>
                  {recipe.description && (
                    <p className="mt-2 line-clamp-2 text-sm text-[var(--muted)]">
                      {recipe.description}
                    </p>
                  )}
                  <div className="mt-4 flex flex-wrap gap-2 text-xs font-bold text-[var(--muted)]">
                    {recipe.servings && <span>{recipe.servings}</span>}
                    {recipe.totalTime && <span>{recipe.totalTime}</span>}
                    <span>
                      {recipe.ingredients.length} ingredient
                      {recipe.ingredients.length === 1 ? "" : "s"}
                    </span>
                  </div>
                </div>
              </Link>
            ))
          ) : (
            <div className="hub-card col-span-2 flex min-h-64 items-center justify-center p-8 text-center text-[var(--muted)] max-md:col-span-1">
              Save your first recipe manually or import one from a website.
            </div>
          )}
        </div>

        {canManage && (
        <aside className="space-y-5">
          <section className="hub-card h-fit p-5 max-md:p-4">
            <div className="flex items-center gap-2">
              <Download size={20} className="text-[var(--sage)]" />
              <h2 className="font-display text-2xl font-semibold">
                Import recipe
              </h2>
            </div>
            <p className="mt-2 text-sm text-[var(--muted)]">
              Paste a recipe URL. We pull ingredients, directions, times, and
              nutrition from structured page data and skip ads and fluff.
            </p>
            <form action={importRecipe} className="mt-5 space-y-3">
              <input
                name="url"
                type="url"
                className="hub-input"
                placeholder="https://example.com/recipe"
                required
              />
              <button className="hub-button w-full">Import recipe</button>
            </form>
          </section>

          <section className="hub-card h-fit p-5 max-md:p-4">
            <div className="flex items-center gap-2">
              <Plus size={20} className="text-[var(--sage)]" />
              <h2 className="font-display text-2xl font-semibold">
                Add manually
              </h2>
            </div>
            <form action={addRecipe} className="mt-5 space-y-3">
              <RecipeFields />
              <button className="hub-button w-full">Save recipe</button>
            </form>
          </section>
        </aside>
        )}
      </div>
    </div>
  );
}
