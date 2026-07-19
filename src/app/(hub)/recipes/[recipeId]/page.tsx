import { and, eq } from "drizzle-orm";
import { ArrowLeft, Clock3, ExternalLink, Trash2, Users } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { RecipeFields } from "@/components/recipe-fields";
import { deleteRecipe, updateRecipe } from "../actions";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import { recipeFromRow, recipeInputFromParsed } from "@/lib/recipes/store";

export default async function RecipeDetailPage({
  params,
}: {
  params: Promise<{ recipeId: string }>;
}) {
  const household = await requireHousehold();
  const { recipeId } = await params;
  const row = await db
    .select()
    .from(recipes)
    .where(
      and(eq(recipes.id, recipeId), eq(recipes.householdId, household.id)),
    )
    .limit(1);
  if (!row[0]) notFound();

  const recipe = recipeFromRow(row[0]);
  const canManage = canManageHousehold(household.role);

  return (
    <div className="mx-auto max-w-4xl pb-10">
      <Link
        href="/recipes"
        className="inline-flex items-center gap-2 text-sm font-bold text-[var(--muted)]"
      >
        <ArrowLeft size={16} /> Back to recipes
      </Link>

      <article className="hub-card mt-5 overflow-hidden">
        {recipe.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={recipe.imageUrl}
            alt=""
            className="max-h-80 w-full object-cover"
          />
        ) : null}
        <div className="p-6 max-md:p-4">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Recipe
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            {recipe.title}
          </h1>
          {recipe.description && (
            <p className="mt-3 text-[var(--muted)]">{recipe.description}</p>
          )}

          <div className="mt-5 flex flex-wrap gap-3 text-sm font-bold">
            {recipe.servings && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[var(--sun-soft)] px-3 py-1.5">
                <Users size={15} /> {recipe.servings}
              </span>
            )}
            {recipe.prepTime && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[var(--tile)] px-3 py-1.5">
                <Clock3 size={15} /> Prep {recipe.prepTime}
              </span>
            )}
            {recipe.cookTime && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[var(--tile)] px-3 py-1.5">
                <Clock3 size={15} /> Cook {recipe.cookTime}
              </span>
            )}
            {recipe.totalTime && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[var(--tile)] px-3 py-1.5">
                <Clock3 size={15} /> Total {recipe.totalTime}
              </span>
            )}
            {recipe.sourceUrl && (
              <a
                href={recipe.sourceUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 rounded-full bg-[var(--blue-soft)] px-3 py-1.5"
              >
                <ExternalLink size={15} /> Source
              </a>
            )}
          </div>

          <div className="mt-8 grid gap-6 md:grid-cols-2">
            <section>
              <h2 className="font-display text-2xl font-semibold">
                Ingredients
              </h2>
              <ul className="mt-3 space-y-2">
                {recipe.ingredients.map((item) => (
                  <li
                    key={item}
                    className="rounded-xl bg-[var(--tile)] px-3 py-2 text-sm font-medium"
                  >
                    {item}
                  </li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="font-display text-2xl font-semibold">
                Directions
              </h2>
              <ol className="mt-3 space-y-3">
                {recipe.directions.map((step, index) => (
                  <li
                    key={`${index}-${step}`}
                    className="rounded-xl bg-[var(--tile)] px-3 py-3 text-sm"
                  >
                    <span className="mr-2 font-extrabold text-[var(--sage)]">
                      {index + 1}.
                    </span>
                    {step}
                  </li>
                ))}
              </ol>
            </section>
          </div>

          {recipe.nutrition && (
            <section className="mt-8">
              <h2 className="font-display text-2xl font-semibold">Nutrition</h2>
              <div className="mt-3 grid gap-2 sm:grid-cols-2">
                {Object.entries(recipe.nutrition).map(([label, value]) => (
                  <div
                    key={label}
                    className="flex items-center justify-between rounded-xl bg-[var(--tile)] px-3 py-2 text-sm"
                  >
                    <span className="font-bold">{label}</span>
                    <span className="text-[var(--muted)]">{value}</span>
                  </div>
                ))}
              </div>
            </section>
          )}

          {recipe.notes && (
            <section className="mt-8 rounded-2xl bg-[var(--sun-soft)]/50 p-4">
              <h2 className="font-display text-xl font-semibold">Notes</h2>
              <p className="mt-2 text-sm">{recipe.notes}</p>
            </section>
          )}
        </div>
      </article>

      {canManage && (
      <section className="hub-card mt-5 p-6 max-md:p-4">
        <h2 className="font-display text-2xl font-semibold">Edit recipe</h2>
        <form
          action={updateRecipe.bind(null, recipe.id)}
          className="mt-5 space-y-3"
        >
          <RecipeFields defaults={recipeInputFromParsed(recipe)} />
          <div className="flex flex-wrap gap-3">
            <button className="hub-button px-6">Save changes</button>
          </div>
        </form>
        <form action={deleteRecipe.bind(null, recipe.id)} className="mt-4">
          <button className="inline-flex items-center gap-1 text-sm font-bold text-[var(--coral)]">
            <Trash2 size={14} /> Delete recipe
          </button>
        </form>
      </section>
      )}
    </div>
  );
}
