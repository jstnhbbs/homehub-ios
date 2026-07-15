"use client";

import { useEffect, useState } from "react";

export function LiveClock({ timezone }: { timezone: string }) {
  const [now, setNow] = useState<Date>();

  useEffect(() => {
    const initial = window.setTimeout(() => setNow(new Date()), 0);
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, []);

  if (!now) return <span className="tabular-nums">--:--</span>;
  return (
    <span className="tabular-nums">
      {new Intl.DateTimeFormat("en-US", {
        timeZone: timezone,
        hour: "numeric",
        minute: "2-digit",
      }).format(now)}
    </span>
  );
}
