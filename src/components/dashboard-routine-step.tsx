"use client";

import { useState, useTransition } from "react";
import { cn } from "@/lib/utils";

export function DashboardRoutineStep({
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
      title={label}
      aria-label={label}
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
        "flex min-h-14 items-center justify-between gap-2 rounded-2xl px-3 text-left transition hover:-translate-y-0.5",
        pending && "opacity-70",
      )}
      style={{
        background: `${color}22`,
        border: `1px solid ${color}55`,
      }}
    >
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-2xl">
        {glyph}
      </span>
      <span
        className="h-8 w-8 shrink-0 rounded-full border-2 bg-[var(--surface)]/55"
        style={{
          borderColor: color,
        }}
        aria-hidden="true"
      />
    </button>
  );
}
