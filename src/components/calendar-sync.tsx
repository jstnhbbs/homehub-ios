"use client";

import { RefreshCw } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export function CalendarSync({
  connected,
  lastSyncedAt,
}: {
  connected: boolean;
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
        if (response.ok) router.refresh();
      } finally {
        setSyncing(false);
      }
    },
    [connected, router, syncing],
  );

  useEffect(() => {
    if (!connected) return;
    async function refresh() {
      const response = await fetch("/api/calendar/sync", { method: "POST" });
      if (response.ok) router.refresh();
    }
    const initial = window.setTimeout(() => void refresh(), 250);
    const timer = window.setInterval(() => void refresh(), 5 * 60 * 1000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [connected, router]);

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
      {syncing
        ? "Syncing"
        : lastSyncedAt
          ? `Updated ${new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" }).format(new Date(lastSyncedAt))}`
          : "Sync now"}
    </button>
  );
}
