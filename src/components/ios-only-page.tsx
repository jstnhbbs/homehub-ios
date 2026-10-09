import { Smartphone } from "lucide-react";
import Link from "next/link";

export function IOSOnlyPage({
  title,
  detail = "This product surface now lives in the Porchlight iOS app. The web app is kept as a lightweight account and backend shell.",
}: {
  title: string;
  detail?: string;
}) {
  return (
    <div className="mx-auto flex min-h-[60dvh] max-w-2xl items-center">
      <section className="hub-card p-7">
        <Smartphone className="text-[var(--sage)]" size={32} />
        <h1 className="font-display mt-4 text-4xl font-semibold max-md:text-3xl">
          {title}
        </h1>
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{detail}</p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link href="/settings" className="hub-button">
            Account settings
          </Link>
          <Link href="/privacy" className="hub-button secondary">
            Privacy
          </Link>
        </div>
      </section>
    </div>
  );
}
