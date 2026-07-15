import { Bell } from "lucide-react";
import { HubNav } from "@/components/hub-nav";
import { LiveClock } from "@/components/live-clock";
import { requireHousehold } from "@/lib/household";

export default async function HubLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const household = await requireHousehold();
  const dateLabel = new Intl.DateTimeFormat("en-US", {
    timeZone: household.timezone,
    weekday: "long",
    month: "long",
    day: "numeric",
  }).format(new Date());

  return (
    <div className="flex h-dvh min-h-[600px] overflow-hidden">
      <HubNav />
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-[78px] shrink-0 items-center justify-between border-b border-[var(--line)] bg-[var(--background)] px-7">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-[var(--muted)]">
              {household.name}
            </p>
            <p className="font-display text-xl font-semibold">{dateLabel}</p>
          </div>
          <div className="flex items-center gap-4">
            <div className="font-display text-3xl font-semibold">
              <LiveClock timezone={household.timezone} />
            </div>
            <button
              type="button"
              aria-label="Notifications"
              className="flex h-12 w-12 items-center justify-center rounded-full border border-[var(--line)] bg-[var(--surface)]"
            >
              <Bell size={21} />
            </button>
          </div>
        </header>
        <main className="min-h-0 flex-1 overflow-auto p-6">{children}</main>
      </div>
    </div>
  );
}
