import Link from "next/link";
import type { ReactNode } from "react";

export function LegalPage({
  title,
  updated,
  children,
}: {
  title: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <main className="mx-auto max-w-3xl px-6 py-12 pb-16">
      <Link href="/sign-in" className="text-sm font-bold text-[var(--sage)]">
        ← Home Hub
      </Link>
      <h1 className="font-display mt-4 text-4xl font-semibold">{title}</h1>
      <p className="mt-2 text-sm text-[var(--muted)]">Last updated: {updated}</p>
      <div className="prose-legal mt-8 space-y-6 text-[15px] leading-7 text-[var(--foreground)]">
        {children}
      </div>
      <footer className="mt-12 flex flex-wrap gap-4 border-t border-[var(--line)] pt-6 text-sm font-bold text-[var(--sage)]">
        <Link href="/privacy">Privacy Policy</Link>
        <Link href="/terms">Terms of Service</Link>
      </footer>
    </main>
  );
}

export function LegalSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section>
      <h2 className="font-display text-2xl font-semibold">{title}</h2>
      <div className="mt-3 space-y-3 text-[var(--muted)]">{children}</div>
    </section>
  );
}
