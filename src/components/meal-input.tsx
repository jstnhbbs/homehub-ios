"use client";

import { Check, Pencil } from "lucide-react";
import Link from "next/link";
import { useRef, useState } from "react";
import { saveMeal } from "@/app/actions";

type RecipeOption = {
  id: string;
  title: string;
};

type MealSlot = "breakfast" | "lunch" | "dinner";

export function MealInput({
  localDate,
  slot,
  initialValue,
  initialRecipeId,
  recipes,
  readOnly = false,
}: {
  localDate: string;
  slot: MealSlot;
  initialValue: string;
  initialRecipeId?: string | null;
  recipes: RecipeOption[];
  readOnly?: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(initialValue);
  const [recipeId, setRecipeId] = useState(initialRecipeId ?? "");
  const titleRef = useRef<HTMLTextAreaElement>(null);

  const items = initialValue
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  if (readOnly) {
    return (
      <div className="flex h-full flex-col space-y-2">
        <div className="min-h-24 flex-1 rounded-xl bg-white/60 px-3 py-3 text-sm font-semibold leading-6">
          {items.length ? (
            <ul className="space-y-0.5">
              {items.map((item, index) => (
                <li
                  key={`${item}-${index}`}
                  className={index === 0 ? "" : "text-[var(--muted)]"}
                >
                  {item}
                </li>
              ))}
            </ul>
          ) : (
            "Not planned"
          )}
        </div>
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
      className="group flex h-full flex-col space-y-2"
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
      <div className="relative min-h-0 flex-1">
        <textarea
          ref={titleRef}
          name="title"
          value={title}
          rows={4}
          maxLength={600}
          onChange={(event) => {
            setTitle(event.target.value);
            setRecipeId("");
            setEditing(true);
          }}
          placeholder="Add meal — one item per line (e.g. sides)"
          aria-label={`${slot} for ${localDate}`}
          onFocus={() => setEditing(true)}
          className="min-h-24 w-full resize-none rounded-xl border border-transparent bg-white/60 px-3 py-2.5 pr-10 text-sm font-semibold leading-6 outline-none transition focus:border-[var(--sage)] focus:bg-white"
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
