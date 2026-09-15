import { useSyncExternalStore } from "react";

export const ACCENT_STORAGE_KEY = "accent";
const ACCENT_EVENT = "accentchange";

export const ACCENT_PALETTES = [
  { id: "sage", label: "Sage", swatch: "#4f7c6d" },
  { id: "ocean", label: "Ocean", swatch: "#3f6f8f" },
  { id: "clay", label: "Clay", swatch: "#b56a4c" },
  { id: "plum", label: "Plum", swatch: "#7a5b7c" },
  { id: "slate", label: "Slate", swatch: "#5c6b7a" },
  { id: "forest", label: "Forest", swatch: "#386641" },
  { id: "teal", label: "Teal", swatch: "#287a78" },
  { id: "indigo", label: "Indigo", swatch: "#555fa3" },
  { id: "rose", label: "Rose", swatch: "#a14f68" },
  { id: "ochre", label: "Ochre", swatch: "#8a6825" },
] as const;

export type AccentPalette = (typeof ACCENT_PALETTES)[number]["id"];

const ACCENT_IDS = new Set<string>(ACCENT_PALETTES.map((palette) => palette.id));

export function isAccentPalette(value: string | null | undefined): value is AccentPalette {
  return !!value && ACCENT_IDS.has(value);
}

function subscribe(callback: () => void) {
  window.addEventListener(ACCENT_EVENT, callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener(ACCENT_EVENT, callback);
    window.removeEventListener("storage", callback);
  };
}

function getSnapshot(): AccentPalette {
  const value = document.documentElement.dataset.accent;
  return isAccentPalette(value) ? value : "sage";
}

function getServerSnapshot(): AccentPalette {
  return "sage";
}

export function setAccent(accent: AccentPalette) {
  document.documentElement.dataset.accent = accent;
  try {
    localStorage.setItem(ACCENT_STORAGE_KEY, accent);
  } catch {
    // Ignore storage failures (private mode, disabled storage).
  }
  window.dispatchEvent(new Event(ACCENT_EVENT));
}

export function useAccent(): AccentPalette {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
