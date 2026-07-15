"use client";

import {
  CalendarDays,
  CheckSquare2,
  ClipboardCheck,
  Home,
  Settings,
  Soup,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const items = [
  { href: "/dashboard", label: "Today", icon: Home },
  { href: "/calendar", label: "Calendar", icon: CalendarDays },
  { href: "/routines", label: "Routines", icon: ClipboardCheck },
  { href: "/chores", label: "Chores", icon: CheckSquare2 },
  { href: "/meals", label: "Meals", icon: Soup },
  { href: "/settings", label: "Settings", icon: Settings },
];

export function HubNav() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Main navigation"
      className="flex w-[104px] shrink-0 flex-col items-center gap-2 border-r border-[var(--line)] bg-[var(--surface)] px-3 py-5"
    >
      <Link
        href="/dashboard"
        className="font-display mb-5 flex h-14 w-14 items-center justify-center rounded-[1.2rem] bg-[var(--sage)] text-2xl font-bold text-white shadow-lg"
        aria-label="Home Hub"
      >
        H
      </Link>
      {items.map(({ href, label, icon: Icon }) => {
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex min-h-[68px] w-full flex-col items-center justify-center gap-1 rounded-2xl text-[11px] font-bold transition",
              active
                ? "bg-[var(--sage-soft)] text-[var(--sage)]"
                : "text-[var(--muted)] hover:bg-black/[0.03]",
            )}
          >
            <Icon size={23} strokeWidth={active ? 2.6 : 2} />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
