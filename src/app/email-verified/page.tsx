import type { Metadata } from "next";
import Link from "next/link";
import { CircleAlert, MailCheck } from "lucide-react";

export const metadata: Metadata = {
  title: "Email confirmed",
  robots: { index: false },
};

// The link in a verification email ends here once the server has checked it. Better Auth adds
// ?error=… when the link is wrong, already used, or older than 24 hours.
export default async function EmailVerifiedPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const failed = Boolean(error);

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center px-4">
      <section className="hub-card w-full p-8 text-center">
        <div className="mx-auto mb-4 grid size-14 place-items-center rounded-full bg-[var(--sage-soft)] text-[var(--sage)]">
          {failed ? <CircleAlert size={28} /> : <MailCheck size={28} />}
        </div>
        <h1 className="font-display text-3xl font-semibold">
          {failed ? "That link didn’t work" : "Email confirmed"}
        </h1>
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">
          {failed
            ? "It may have expired or already been used. Open Beacon, go to Settings, and ask for a new confirmation email."
            : "Thanks. Your email address is confirmed. You can close this page and go back to Beacon."}
        </p>
        <Link href="/" className="hub-button secondary mt-6 inline-flex">
          Open Beacon on the web
        </Link>
      </section>
    </main>
  );
}
