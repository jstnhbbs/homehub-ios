"use client";

import { useEffect } from "react";

// The phone app registers the tugboat:// scheme and opens Today for this address.
export const OPEN_APP_URL = "tugboat://widget/dashboard";

/**
 * Tries to open the phone app as soon as the page loads, on an iPhone or iPad only (a computer has no app to
 * open, and would show an error). Safari asks "Open in Tugboat?" first. The visible button is the fallback for
 * when that is dismissed or the browser won't open an app without a tap.
 */
export function OpenAppOnLoad() {
  useEffect(() => {
    const iOS =
      /iPhone|iPad|iPod/.test(navigator.userAgent) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
    if (iOS) window.location.href = OPEN_APP_URL;
  }, []);
  return null;
}
