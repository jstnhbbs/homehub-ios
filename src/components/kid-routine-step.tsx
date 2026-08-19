"use client";

import { Check } from "lucide-react";
import { useState, useTransition } from "react";
import { cn } from "@/lib/utils";

export function KidRoutineStep({
  label,
  glyph,
  color = "#4f7c6d",
  onToggle,
}: {
  label: string;
  glyph: string;
  color?: string;
  onToggle: (checked: boolean) => Promise<void>;
}) {
  const [done, setDone] = useState(false);
  const [pending, startTransition] = useTransition();

  if (done) return null;

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        if (pending) return;
        setDone(true);
        startTransition(async () => {
          try {
            await onToggle(true);
          } catch {
            setDone(false);
          }
        });
      }}
      className={cn(
        "group grid min-h-36 grid-cols-[5.25rem_1fr] items-center gap-4 rounded-[1.5rem] border-2 border-transparent bg-[var(--tile)] p-4 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-[var(--sage)] hover:bg-[var(--surface-strong)] max-sm:grid-cols-1 max-sm:text-center",
        pending && "opacity-70",
      )}
    >
      <span
        className="flex aspect-square h-20 items-center justify-center rounded-[1.35rem] text-5xl shadow-inner max-sm:mx-auto"
        style={{ background: `${color}22` }}
        aria-hidden="true"
      >
        {glyph}
      </span>
      <span className="min-w-0">
        <span className="block break-words text-2xl font-extrabold leading-tight max-sm:text-xl">
          {label}
        </span>
        <span className="mt-3 inline-flex items-center gap-2 rounded-full bg-[var(--sage-soft)] px-3 py-1 text-xs font-extrabold uppercase tracking-[0.12em] text-[var(--sage)]">
          <Check size={14} strokeWidth={3} />
          Tap when done
        </span>
      </span>
    </button>
  );
}
