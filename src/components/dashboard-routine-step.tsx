"use client";

import { Check } from "lucide-react";
import { useEffect, useRef, useState, useTransition } from "react";
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
  const [celebrating, setCelebrating] = useState(false);
  const [pending, startTransition] = useTransition();
  const doneTimer = useRef<number | null>(null);

  useEffect(
    () => () => {
      if (doneTimer.current) {
        window.clearTimeout(doneTimer.current);
      }
    },
    [],
  );

  if (done) return null;

  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      disabled={pending}
      onClick={() => {
        if (pending) return;
        setCelebrating(true);
        doneTimer.current = window.setTimeout(() => setDone(true), 800);
        startTransition(async () => {
          try {
            await onToggle(true);
          } catch {
            if (doneTimer.current) {
              window.clearTimeout(doneTimer.current);
            }
            setCelebrating(false);
            setDone(false);
          }
        });
      }}
      className={cn(
        "routine-celebration group relative flex min-h-14 items-center justify-between gap-2 overflow-hidden rounded-2xl px-3 text-left transition hover:-translate-y-0.5",
        celebrating && "is-celebrating pointer-events-none",
        pending && "opacity-70",
      )}
      style={{
        "--routine-color": color,
        background: `${color}22`,
        border: `1px solid ${color}55`,
      } as React.CSSProperties}
    >
      <span className="routine-celebration__mini-sparkles" aria-hidden="true">
        <span>✨</span>
        <span>⭐</span>
        <span>✨</span>
      </span>
      <span className="routine-celebration__glyph flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-2xl">
        {glyph}
      </span>
      <span
        className="routine-celebration__check flex h-8 w-8 shrink-0 items-center justify-center rounded-full border-2 bg-[var(--surface)]/55"
        style={{
          borderColor: color,
        }}
        aria-hidden="true"
      >
        {celebrating && <Check size={16} strokeWidth={3} />}
      </span>
    </button>
  );
}
