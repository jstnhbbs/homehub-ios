import { CalendarDays, CheckCircle2, Soup } from "lucide-react";
import { redirect } from "next/navigation";
import { AuthForm } from "@/components/auth-form";
import { ThemeToggle } from "@/components/theme-toggle";
import { getSession } from "@/lib/household";

export default async function SignInPage() {
  if (await getSession()) redirect("/");
  return (
    <main className="grid min-h-dvh lg:grid-cols-[1.15fr_0.85fr]">
      <section className="relative hidden overflow-hidden bg-[var(--hero)] p-14 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="absolute -right-24 -top-28 h-80 w-80 rounded-full bg-[var(--sun)]/80" />
        <div className="font-display relative text-3xl font-bold">Home Hub</div>
        <div className="relative max-w-xl">
          <p className="font-display text-6xl font-semibold leading-[1.02]">
            A calmer way to run the family week.
          </p>
          <div className="mt-10 grid grid-cols-3 gap-4">
            {[
              [CalendarDays, "Everyone's day"],
              [CheckCircle2, "Routines done"],
              [Soup, "Meals planned"],
            ].map(([Icon, label]) => {
              const IconComponent = Icon as typeof CalendarDays;
              return (
                <div key={String(label)} className="rounded-2xl bg-white/10 p-4">
                  <IconComponent className="mb-4" />
                  <p className="font-bold">{String(label)}</p>
                </div>
              );
            })}
          </div>
        </div>
        <p className="relative text-sm text-white/70">
          Designed for the family iPad.
        </p>
      </section>
      <section className="relative flex items-center justify-center p-6">
        <div className="absolute right-4 top-4">
          <ThemeToggle />
        </div>
        <div className="w-full max-w-md">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Welcome home
          </p>
          <h1 className="font-display mt-2 text-5xl font-semibold">
            Your week, together.
          </h1>
          <p className="mt-3 text-[var(--muted)]">
            Sign in with a parent account to open your household hub.
          </p>
          <AuthForm />
          <p className="mt-8 text-center text-xs leading-5 text-[var(--muted)]">
            <a href="/privacy" className="font-bold text-[var(--sage)]">
              Privacy Policy
            </a>
            {" · "}
            <a href="/terms" className="font-bold text-[var(--sage)]">
              Terms of Service
            </a>
          </p>
        </div>
      </section>
    </main>
  );
}
