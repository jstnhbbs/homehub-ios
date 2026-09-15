"use client";

import { Moon, Sun } from "lucide-react";
import { ACCENT_PALETTES, setAccent, useAccent } from "@/lib/accent";
import { setTheme, useTheme } from "@/lib/theme";

export function ThemeSetting() {
  const theme = useTheme();
  const accent = useAccent();
  const isDark = theme === "dark";

  return (
    <div className="mt-5 space-y-3">
      <div className="flex items-center justify-between gap-4 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4">
        <div className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--sage-soft)] text-[var(--sage)]">
            {isDark ? <Moon size={20} /> : <Sun size={20} />}
          </span>
          <div className="min-w-0">
            <p className="font-bold">Dark mode</p>
            <p className="text-sm text-[var(--muted)]">
              {isDark ? "On · neutral grey surfaces" : "Off · light theme"}
            </p>
          </div>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={isDark}
          aria-label="Toggle dark mode"
          onClick={() => setTheme(isDark ? "light" : "dark")}
          className="relative h-8 w-14 shrink-0 rounded-full border border-[var(--line)] transition-colors"
          style={{ background: isDark ? "var(--sage)" : "var(--surface-strong)" }}
        >
          <span
            className="absolute top-1/2 h-6 w-6 -translate-y-1/2 rounded-full bg-[var(--tile-solid)] shadow transition-[left]"
            style={{ left: isDark ? "1.75rem" : "0.15rem" }}
          />
        </button>
      </div>

      <div className="rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4">
        <p className="font-bold">Accent color</p>
        <p className="mt-1 text-sm text-[var(--muted)]">
          Used for buttons, links, and highlights on this device.
        </p>
        <div className="mt-4 flex flex-wrap gap-3">
          {ACCENT_PALETTES.map((palette) => {
            const selected = accent === palette.id;
            return (
              <button
                key={palette.id}
                type="button"
                aria-pressed={selected}
                aria-label={palette.label}
                onClick={() => setAccent(palette.id)}
                className="flex flex-col items-center gap-1.5"
              >
                <span
                  className={`flex h-9 w-9 items-center justify-center rounded-full text-white ${
                    selected ? "ring-2 ring-[var(--foreground)] ring-offset-2 ring-offset-[var(--surface)]" : ""
                  }`}
                  style={{ background: palette.swatch }}
                >
                  {selected ? (
                    <span className="text-sm font-extrabold" aria-hidden>
                      ✓
                    </span>
                  ) : null}
                </span>
                <span className="text-xs font-bold text-[var(--muted)]">
                  {palette.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
