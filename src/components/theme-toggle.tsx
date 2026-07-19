"use client";

import { Moon, Sun } from "lucide-react";
import { setTheme, useTheme } from "@/lib/theme";
import { cn } from "@/lib/utils";

export function ThemeToggle({ className }: { className?: string }) {
  const theme = useTheme();
  const isDark = theme === "dark";

  return (
    <button
      type="button"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      aria-label={isDark ? "Switch to light mode" : "Switch to dark mode"}
      title={isDark ? "Switch to light mode" : "Switch to dark mode"}
      className={cn(
        "flex h-12 w-12 items-center justify-center rounded-full border border-[var(--line)] bg-[var(--surface)] text-[var(--foreground)] transition hover:bg-[var(--tile-quiet)]",
        className,
      )}
    >
      {isDark ? <Sun size={20} /> : <Moon size={20} />}
    </button>
  );
}
