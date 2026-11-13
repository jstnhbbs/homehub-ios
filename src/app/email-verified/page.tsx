import type { Metadata } from "next";
import Link from "next/link";
import { CircleAlert, MailCheck } from "lucide-react";
import { OPEN_APP_URL, OpenAppOnLoad } from "./open-app";

export const metadata: Metadata = {
  title: "Email confirmed",
  robots: { index: false },
};

// The link in a verification email ends here once the server has checked it. Better Auth adds
// ?error=… when the link is wrong, already used, or older than 24 hours. On an iPhone or iPad the page
// opens the Tugboat app by itself (and offers a button), instead of leaving people on the web sign-in.
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
            ? "It may have expired or already been used. Open Tugboat, go to Settings, and ask for a new confirmation email."
            : "Thanks. Your email address is confirmed. Tugboat should open on its own; if it doesn’t, tap Open Tugboat."}
        </p>
        <a href={OPEN_APP_URL} className="hub-button mt-6 inline-flex">
          Open Tugboat
        </a>
        <p className="mt-4 text-xs text-[var(--muted)]">
          On a computer?{" "}
          <Link href="/" className="font-bold text-[var(--sage)]">
            Use Tugboat on the web
          </Link>
        </p>
        <OpenAppOnLoad />
      </section>
    </main>
  );
}
