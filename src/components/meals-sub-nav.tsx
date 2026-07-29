"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const tabs = [
  { href: "/meals", label: "Weekly plan" },
  { href: "/meals/snacks", label: "Snacks" },
  { href: "/meals/recipes", label: "Recipes" },
] as const;

function isActiveTab(pathname: string, href: string) {
  if (href === "/meals") return pathname === "/meals";
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function MealsSubNav() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Food sections"
      className="mb-6 flex gap-2 rounded-2xl bg-[var(--tile-quiet)] p-1.5 max-md:mb-4"
    >
      {tabs.map(({ href, label }) => {
        const active = isActiveTab(pathname, href);
        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex-1 rounded-xl px-4 py-2.5 text-center text-sm font-bold transition",
              active
                ? "bg-[var(--surface)] text-[var(--foreground)] shadow-sm"
                : "text-[var(--muted)] hover:text-[var(--foreground)]",
            )}
          >
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
