"use client";

import { RefreshCw } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { calendarSyncCooldownMs, calendarSyncIntervalMs } from "@/lib/calendar/sync-interval";

const SESSION_SYNC_KEY = "homehub:calendar-sync-at";

function recentAutoSync(lastSyncedAt: string | undefined, cooldownMs: number) {
  if (cooldownMs <= 0) return true;
  const storedAt = sessionStorage.getItem(SESSION_SYNC_KEY);
  if (storedAt && Date.now() - Number(storedAt) < cooldownMs) {
    return true;
  }
  if (
    lastSyncedAt &&
    Date.now() - new Date(lastSyncedAt).getTime() < cooldownMs
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
  syncIntervalMinutes,
}: {
  connected: boolean;
  updatedLabel?: string;
  lastSyncedAt?: string;
  syncIntervalMinutes: number;
}) {
  const router = useRouter();
  const [syncing, setSyncing] = useState(false);
  const syncIntervalMs = calendarSyncIntervalMs(syncIntervalMinutes);
  const syncCooldownMs = calendarSyncCooldownMs(syncIntervalMinutes);

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
    if (!connected || syncIntervalMinutes <= 0) return;

    async function refresh() {
      if (recentAutoSync(lastSyncedAt, syncCooldownMs)) return;
      const response = await fetch("/api/calendar/sync", { method: "POST" });
      if (response.ok) {
        markAutoSync();
        router.refresh();
      }
    }

    const initial = window.setTimeout(() => void refresh(), 250);
    const timer = window.setInterval(() => void refresh(), syncIntervalMs);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [
    connected,
    lastSyncedAt,
    router,
    syncCooldownMs,
    syncIntervalMinutes,
    syncIntervalMs,
  ]);

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
