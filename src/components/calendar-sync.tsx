"use client";

import { RefreshCw } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

const AUTO_SYNC_INTERVAL_MS = 5 * 60 * 1000;
const AUTO_SYNC_COOLDOWN_MS = 4 * 60 * 1000;
const SESSION_SYNC_KEY = "homehub:calendar-sync-at";

function recentAutoSync(lastSyncedAt?: string) {
  const storedAt = sessionStorage.getItem(SESSION_SYNC_KEY);
  if (storedAt && Date.now() - Number(storedAt) < AUTO_SYNC_COOLDOWN_MS) {
    return true;
  }
  if (
    lastSyncedAt &&
    Date.now() - new Date(lastSyncedAt).getTime() < AUTO_SYNC_COOLDOWN_MS
  ) {
    return true;
  }
  return false;
}

function markAutoSync() {
  sessionStorage.setItem(SESSION_SYNC_KEY, String(Date.now()));
}

export function CalendarSync({
  connected,
  updatedLabel,
  lastSyncedAt,
}: {
  connected: boolean;
  updatedLabel?: string;
  lastSyncedAt?: string;
}) {
  const router = useRouter();
  const [syncing, setSyncing] = useState(false);

  const sync = useCallback(
    async (force = false) => {
      if (!connected || syncing) return;
      setSyncing(true);
      try {
        const response = await fetch(`/api/calendar/sync${force ? "?force=true" : ""}`, {
          method: "POST",
        });
        if (response.ok) {
          if (!force) markAutoSync();
          router.refresh();
        }
      } finally {
        setSyncing(false);
      }
    },
    [connected, router, syncing],
  );

  useEffect(() => {
    if (!connected) return;

    async function refresh() {
      if (recentAutoSync(lastSyncedAt)) return;
      const response = await fetch("/api/calendar/sync", { method: "POST" });
      if (response.ok) {
        markAutoSync();
        router.refresh();
      }
    }

    const initial = window.setTimeout(() => void refresh(), 250);
    const timer = window.setInterval(() => void refresh(), AUTO_SYNC_INTERVAL_MS);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [connected, lastSyncedAt, router]);

  if (!connected) {
    return (
      <span className="rounded-full bg-[var(--sun-soft)] px-3 py-1.5 text-xs font-bold">
        Calendar not connected
      </span>
    );
  }
  return (
    <button
      type="button"
      onClick={() => void sync(true)}
      disabled={syncing}
      className="flex items-center gap-2 rounded-full bg-[var(--sage-soft)] px-3 py-1.5 text-xs font-bold text-[var(--sage)]"
    >
      <RefreshCw size={14} className={syncing ? "animate-spin" : ""} />
      {syncing ? "Syncing" : (updatedLabel ?? "Sync now")}
    </button>
  );
}
