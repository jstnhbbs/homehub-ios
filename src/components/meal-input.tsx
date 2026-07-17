"use client";

import { Check, Pencil } from "lucide-react";
import Link from "next/link";
import { useRef, useState } from "react";
import { saveMeal } from "@/app/actions";

type RecipeOption = {
  id: string;
  title: string;
};

export function MealInput({
  localDate,
  slot,
  initialValue,
  initialRecipeId,
  recipes,
  readOnly = false,
}: {
  localDate: string;
  slot: "breakfast" | "lunch" | "dinner" | "snack";
  initialValue: string;
  initialRecipeId?: string | null;
  recipes: RecipeOption[];
  readOnly?: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(initialValue);
  const [recipeId, setRecipeId] = useState(initialRecipeId ?? "");
  const titleRef = useRef<HTMLInputElement>(null);

  if (readOnly) {
    return (
      <div className="space-y-2">
        <p className="min-h-12 rounded-xl bg-white/60 px-3 py-3 text-sm font-semibold">
          {initialValue || "Not planned"}
        </p>
        {initialRecipeId && initialValue && (
          <Link
            href={`/recipes/${initialRecipeId}`}
            className="block truncate text-[11px] font-bold text-[var(--sage)]"
          >
            View recipe
          </Link>
        )}
      </div>
    );
  }

  return (
    <form
      action={async (formData) => {
        await saveMeal(formData);
        setEditing(false);
      }}
      className="group relative space-y-2"
    >
      <input type="hidden" name="localDate" value={localDate} />
      <input type="hidden" name="slot" value={slot} />
      <input type="hidden" name="recipeId" value={recipeId} />
      {recipes.length > 0 && (
        <select
          value={recipeId}
          onChange={(event) => {
            const nextRecipeId = event.target.value;
            setRecipeId(nextRecipeId);
            const recipe = recipes.find((item) => item.id === nextRecipeId);
            if (recipe) {
              setTitle(recipe.title);
              if (titleRef.current) titleRef.current.value = recipe.title;
            }
            setEditing(true);
          }}
          className="hub-input !min-h-9 w-full !rounded-lg !py-1.5 text-xs"
          aria-label={`Choose a saved recipe for ${slot}`}
        >
          <option value="">Choose a saved recipe</option>
          {recipes.map((recipe) => (
            <option key={recipe.id} value={recipe.id}>
              {recipe.title}
            </option>
          ))}
        </select>
      )}
      <div className="relative">
        <input
          ref={titleRef}
          name="title"
          value={title}
          onChange={(event) => {
            setTitle(event.target.value);
            setRecipeId("");
            setEditing(true);
          }}
          placeholder="Add meal"
          aria-label={`${slot} for ${localDate}`}
          onFocus={() => setEditing(true)}
          className="min-h-12 w-full rounded-xl border border-transparent bg-white/60 px-3 pr-10 text-sm font-semibold outline-none transition focus:border-[var(--sage)] focus:bg-white"
        />
        <button
          type="submit"
          aria-label="Save meal"
          className="absolute right-2 top-2 flex h-8 w-8 items-center justify-center rounded-full text-[var(--sage)] opacity-50 transition group-focus-within:opacity-100"
        >
          {editing ? <Check size={17} /> : <Pencil size={14} />}
        </button>
      </div>
      {initialRecipeId && initialValue && (
        <Link
          href={`/recipes/${initialRecipeId}`}
          className="block truncate text-[11px] font-bold text-[var(--sage)]"
        >
          View recipe
        </Link>
      )}
    </form>
  );
}
