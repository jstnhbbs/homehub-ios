"use client";

import { Check, Pencil } from "lucide-react";
import { useState } from "react";
import { saveMeal } from "@/app/actions";

export function MealInput({
  localDate,
  slot,
  initialValue,
}: {
  localDate: string;
  slot: "breakfast" | "lunch" | "dinner" | "snack";
  initialValue: string;
}) {
  const [editing, setEditing] = useState(false);
  return (
    <form
      action={async (formData) => {
        await saveMeal(formData);
        setEditing(false);
      }}
      className="group relative"
    >
      <input type="hidden" name="localDate" value={localDate} />
      <input type="hidden" name="slot" value={slot} />
      <input
        name="title"
        defaultValue={initialValue}
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
    </form>
  );
}
