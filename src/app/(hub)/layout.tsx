import { Bell } from "lucide-react";
import { HubNav } from "@/components/hub-nav";
import { LiveClock } from "@/components/live-clock";
import { SignOutButton } from "@/components/sign-out-button";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold, isGuest } from "@/lib/household-roles";

export default async function HubLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const household = await requireHousehold();
  const showSettings = canManageHousehold(household.role);
  const dateLabel = new Intl.DateTimeFormat("en-US", {
    timeZone: household.timezone,
    weekday: "long",
    month: "long",
    day: "numeric",
  }).format(new Date());

  return (
    <div className="flex h-dvh min-h-[600px] overflow-hidden max-md:min-h-0 max-md:flex-col">
      <HubNav showSettings={showSettings} />
      <div className="flex min-w-0 flex-1 flex-col max-md:min-h-0 max-md:order-1">
        <header className="flex h-[78px] shrink-0 items-center justify-between border-b border-[var(--line)] bg-[var(--background)] px-7 max-md:h-[64px] max-md:px-4">
          <div className="min-w-0">
            <p className="truncate text-xs font-bold uppercase tracking-[0.16em] text-[var(--muted)] max-md:text-[10px]">
              {household.name}
              {isGuest(household.role) && (
                <span className="ml-2 rounded-full bg-[var(--sun-soft)] px-2 py-0.5 text-[10px] text-[var(--foreground)]">
                  Guest
                </span>
              )}
            </p>
            <p className="font-display truncate text-xl font-semibold max-md:text-base">
              {dateLabel}
            </p>
          </div>
          <div className="ml-3 flex shrink-0 items-center gap-4 max-md:gap-2">
            <div className="font-display text-3xl font-semibold max-md:text-2xl">
              <LiveClock timezone={household.timezone} />
            </div>
            {isGuest(household.role) && (
              <SignOutButton className="hub-button secondary !min-h-10 !px-4 text-xs" />
            )}
            <button
              type="button"
              aria-label="Notifications"
              className="flex h-12 w-12 items-center justify-center rounded-full border border-[var(--line)] bg-[var(--surface)] max-md:hidden"
            >
              <Bell size={21} />
            </button>
          </div>
        </header>
        <main className="min-h-0 flex-1 overflow-auto p-6 max-md:p-3">
          {children}
        </main>
      </div>
    </div>
  );
}
