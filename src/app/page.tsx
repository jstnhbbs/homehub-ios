import {
  BookOpen,
  CalendarDays,
  CheckSquare2,
  ClipboardCheck,
  Soup,
} from "lucide-react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentHousehold, getSession } from "@/lib/household";

const features = [
  {
    icon: CalendarDays,
    title: "Shared calendar",
    description:
      "Connect Apple or Google calendars for two-way sync on the family dashboard.",
  },
  {
    icon: ClipboardCheck,
    title: "Routines",
    description:
      "Morning, afternoon, and bedtime checklists for each child.",
  },
  {
    icon: CheckSquare2,
    title: "Chores",
    description: "Daily and weekly chores assigned to family members.",
  },
  {
    icon: Soup,
    title: "Meals & recipes",
    description: "Plan the week and save recipes your family actually uses.",
  },
];

export default async function Home() {
  const session = await getSession();
  if (session) {
    const household = await getCurrentHousehold();
    redirect(household ? "/dashboard" : "/onboarding");
  }

  return (
    <main className="min-h-dvh">
      <header className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-6 py-6">
        <div className="font-display text-2xl font-bold">Home Hub</div>
        <Link href="/sign-in" className="hub-button px-5">
          Sign in
        </Link>
      </header>

      <section className="mx-auto max-w-6xl px-6 pb-10 pt-4">
        <div className="hub-card overflow-hidden p-8 md:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Family dashboard
          </p>
          <h1 className="font-display mt-3 max-w-3xl text-5xl font-semibold leading-tight max-md:text-4xl">
            A calmer way to run the family week.
          </h1>
          <p className="mt-5 max-w-2xl text-lg leading-8 text-[var(--muted)]">
            Home Hub brings calendars, routines, chores, meals, and recipes
            together on one iPad-friendly screen so everyone knows what&apos;s
            happening today.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/sign-in" className="hub-button px-6">
              Open your household
            </Link>
            <Link
              href="/privacy"
              className="rounded-full border border-[var(--line)] bg-white/60 px-6 py-3 text-sm font-bold"
            >
              Privacy Policy
            </Link>
          </div>
        </div>

        <div className="mt-8 grid gap-5 md:grid-cols-2">
          {features.map(({ icon: Icon, title, description }) => (
            <article key={title} className="hub-card p-6">
              <Icon className="text-[var(--sage)]" size={28} />
              <h2 className="font-display mt-4 text-2xl font-semibold">
                {title}
              </h2>
              <p className="mt-2 text-sm leading-7 text-[var(--muted)]">
                {description}
              </p>
            </article>
          ))}
        </div>

        <section className="hub-card mt-8 p-6">
          <div className="flex items-start gap-3">
            <BookOpen className="mt-1 shrink-0 text-[var(--blue)]" size={24} />
            <div>
              <h2 className="font-display text-2xl font-semibold">
                Built for parents
              </h2>
              <p className="mt-2 text-sm leading-7 text-[var(--muted)]">
                Parents sign in to manage the hub. Children appear as family
                profiles without needing their own accounts. Calendar
                credentials are encrypted before storage.
              </p>
            </div>
          </div>
        </section>
      </section>

      <footer className="border-t border-[var(--line)] px-6 py-8 text-center text-sm text-[var(--muted)]">
        <p>
          <Link href="/privacy" className="font-bold text-[var(--sage)]">
            Privacy Policy
          </Link>
          {" · "}
          <Link href="/terms" className="font-bold text-[var(--sage)]">
            Terms of Service
          </Link>
        </p>
      </footer>
    </main>
  );
}
