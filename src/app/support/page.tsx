import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/legal-page";
import { APP_NAME, CONTACT_EMAIL } from "@/lib/app-info";

export const metadata: Metadata = {
  title: "Support",
  description: `Help and contact details for ${APP_NAME}.`,
};

const link = "font-bold text-[var(--sage)]";

export default function SupportPage() {
  return (
    <LegalPage title="Support" updated="October 14, 2026">
      <p>
        {APP_NAME} is made by Justin Hobbs, an individual developer. If something
        is not working, or you have a question about your family&apos;s data, write to{" "}
        <a className={link} href={`mailto:${CONTACT_EMAIL}`}>
          {CONTACT_EMAIL}
        </a>
        . Include the email address you sign in with and what you were doing when
        the problem happened.
      </p>

      <LegalSection title="Getting started">
        <p>
          Create an account in the app, then either start a household or join one
          with an invite code from a parent. Parents and owners can find the
          codes in Settings → Family. Guests can view everything and log
          activity, such as naps and check-offs, but cannot change shared data.
        </p>
      </LegalSection>

      <LegalSection title="Common questions">
        <p>
          <strong className="text-[var(--foreground)]">My calendar events are missing.</strong>{" "}
          {APP_NAME} reads the calendars on the device. Open Settings → Calendar &amp;
          Reminders, allow access, and choose which calendars to show. Each
          device is set up separately.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">I forgot my password.</strong>{" "}
          Email us from the address you signed up with and we will help you back in.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">How do I delete my data?</strong>{" "}
          In the app, open Settings → Account → Delete Account. It removes your
          account, and a household you are the only member of, along with its
          photos. The{" "}
          <Link className={link} href="/privacy">
            Privacy Policy
          </Link>{" "}
          has the details.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">Can I export my family&apos;s data?</strong>{" "}
          Yes. Settings has a data export for the whole household.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
