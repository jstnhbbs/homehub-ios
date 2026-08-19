"use client";

import { Plus, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import {
  ROUTINE_GLYPHS,
  routineStepDisplay,
  routineStepStorageValue,
} from "@/lib/routine-glyphs";

type StepDraft = {
  id: string;
  glyph: string;
  label: string;
};

function draftFromLabel(label: string, index: number): StepDraft {
  const parsed = routineStepDisplay(label);
  return {
    id: `${index}-${parsed.label}`,
    glyph: parsed.glyph,
    label: parsed.label,
  };
}

export function RoutineStepsField({
  name = "steps",
  initialSteps,
}: {
  name?: string;
  initialSteps: string[];
}) {
  const [steps, setSteps] = useState<StepDraft[]>(
    (initialSteps.length ? initialSteps : [""]).map(draftFromLabel),
  );
  const serialized = useMemo(
    () =>
      steps
        .map((step) =>
          routineStepStorageValue({
            glyph: step.glyph,
            label: step.label,
          }),
        )
        .filter(Boolean)
        .join("\n"),
    [steps],
  );

  return (
    <div className="space-y-3">
      <input type="hidden" name={name} value={serialized} />
      {steps.map((step, index) => (
        <div
          key={step.id}
          className="rounded-2xl border border-[var(--line)] bg-[var(--surface-strong)] p-3"
        >
          <div className="grid grid-cols-[4.25rem_1fr_auto] gap-2 max-sm:grid-cols-[3.75rem_1fr]">
            <select
              aria-label="Step picture"
              className="hub-input h-12 px-2 text-center text-2xl"
              value={step.glyph}
              onChange={(event) => {
                const glyph = event.target.value;
                setSteps((current) =>
                  current.map((item, itemIndex) =>
                    itemIndex === index ? { ...item, glyph } : item,
                  ),
                );
              }}
            >
              {ROUTINE_GLYPHS.map((option) => (
                <option key={option.glyph} value={option.glyph}>
                  {option.glyph}
                </option>
              ))}
            </select>
            <input
              className="hub-input"
              value={step.label}
              placeholder={ROUTINE_GLYPHS[index]?.label ?? "Routine step"}
              required={index === 0}
              onChange={(event) => {
                const label = event.target.value;
                setSteps((current) =>
                  current.map((item, itemIndex) => {
                    if (itemIndex !== index) return item;
                    const previousGlyph = routineStepDisplay(item.label).glyph;
                    const nextGlyph =
                      item.glyph === previousGlyph || !item.label
                        ? routineStepDisplay(label).glyph
                        : item.glyph;
                    return { ...item, label, glyph: nextGlyph };
                  }),
                );
              }}
            />
            <button
              type="button"
              className="flex h-12 w-12 items-center justify-center rounded-xl text-[var(--muted)] hover:bg-[var(--tile-quiet)] hover:text-[var(--coral)] max-sm:col-start-2 max-sm:ml-auto"
              aria-label="Remove step"
              onClick={() => {
                setSteps((current) =>
                  current.length === 1
                    ? [{ id: crypto.randomUUID(), glyph: "⭐", label: "" }]
                    : current.filter((_, itemIndex) => itemIndex !== index),
                );
              }}
            >
              <Trash2 size={17} />
            </button>
          </div>
          <div className="mt-2 grid grid-cols-5 gap-1">
            {ROUTINE_GLYPHS.slice(0, 15).map((option) => (
              <button
                key={option.glyph}
                type="button"
                title={option.label}
                aria-label={option.label}
                className="flex h-10 items-center justify-center rounded-xl bg-[var(--tile)] text-2xl hover:bg-[var(--sage-soft)]"
                onClick={() => {
                  setSteps((current) =>
                    current.map((item, itemIndex) =>
                      itemIndex === index
                        ? { ...item, glyph: option.glyph }
                        : item,
                    ),
                  );
                }}
              >
                {option.glyph}
              </button>
            ))}
          </div>
        </div>
      ))}
      <button
        type="button"
        className="hub-button secondary w-full"
        onClick={() =>
          setSteps((current) => [
            ...current,
            { id: crypto.randomUUID(), glyph: "⭐", label: "" },
          ])
        }
      >
        <Plus size={18} /> Add step
      </button>
    </div>
  );
}
