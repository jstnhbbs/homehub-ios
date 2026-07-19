"use client";

import { Check } from "lucide-react";
import { useState, useTransition } from "react";
import { cn } from "@/lib/utils";

export function CheckItem({
  label,
  initialChecked,
  color = "#4f7c6d",
  onToggle,
  detail,
  disabled = false,
  removeWhenChecked = false,
}: {
  label: string;
  initialChecked: boolean;
  color?: string;
  detail?: string;
  disabled?: boolean;
  removeWhenChecked?: boolean;
  onToggle: (checked: boolean) => Promise<void>;
}) {
  const [checked, setChecked] = useState(initialChecked);
  const [pending, startTransition] = useTransition();
  const inactive = disabled || pending;

  if (removeWhenChecked && checked) {
    return null;
  }

  return (
    <button
      type="button"
      aria-pressed={checked}
      disabled={inactive}
      onClick={() => {
        if (removeWhenChecked) {
          if (checked || inactive) return;
          setChecked(true);
          startTransition(async () => {
            try {
              await onToggle(true);
            } catch {
              setChecked(false);
            }
          });
          return;
        }

        const next = !checked;
        setChecked(next);
        startTransition(async () => {
          try {
            await onToggle(next);
          } catch {
            setChecked(!next);
          }
        });
      }}
      className={cn(
        "flex min-h-14 w-full items-center gap-3 rounded-2xl px-3 text-left transition",
        checked ? "bg-[var(--tile-quiet)] text-[var(--muted)]" : "bg-[var(--tile)]",
        inactive && "opacity-70",
        disabled && "cursor-not-allowed",
      )}
    >
      <span
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border-2"
        style={{
          borderColor: color,
          background: checked ? color : "transparent",
          color: "white",
        }}
      >
        {checked && <Check size={18} strokeWidth={3} />}
      </span>
      <span
        className={cn(
          "min-w-0 flex-1 truncate font-bold",
          checked && "line-through",
        )}
      >
        {label}
      </span>
      {detail && (
        <span className="max-w-[35%] shrink-0 truncate text-xs font-semibold text-[var(--muted)]">
          {detail}
        </span>
      )}
    </button>
  );
}
