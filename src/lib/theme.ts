import { useSyncExternalStore } from "react";

export type Theme = "light" | "dark";

export const THEME_STORAGE_KEY = "theme";
const THEME_EVENT = "themechange";

function subscribe(callback: () => void) {
  window.addEventListener(THEME_EVENT, callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener(THEME_EVENT, callback);
    window.removeEventListener("storage", callback);
  };
}

function getSnapshot(): Theme {
  return document.documentElement.dataset.theme === "dark" ? "dark" : "light";
}

function getServerSnapshot(): Theme {
  return "light";
}

export function setTheme(theme: Theme) {
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch {
    // Ignore storage failures (private mode, disabled storage).
  }
  window.dispatchEvent(new Event(THEME_EVENT));
}

// Reads the active theme from the DOM so every control stays in sync,
// while remaining hydration-safe (server render assumes light).
export function useTheme(): Theme {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
