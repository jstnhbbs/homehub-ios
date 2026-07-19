"use client";

import { Moon, Sun } from "lucide-react";
import { setTheme, useTheme } from "@/lib/theme";

export function ThemeSetting() {
  const theme = useTheme();
  const isDark = theme === "dark";

  return (
    <div className="mt-5 flex items-center justify-between gap-4 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4">
      <div className="flex items-center gap-3">
        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--sage-soft)] text-[var(--sage)]">
          {isDark ? <Moon size={20} /> : <Sun size={20} />}
        </span>
        <div className="min-w-0">
          <p className="font-bold">Dark mode</p>
          <p className="text-sm text-[var(--muted)]">
            {isDark ? "On" : "Off"} · easier on the eyes at night.
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
  );
}
