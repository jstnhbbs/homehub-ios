import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/legal-page";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Home Hub collects, uses, and protects family data.",
};

export default function PrivacyPolicyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="July 15, 2026">
      <p>
        Home Hub is a family dashboard for calendars, routines, chores, meals,
        and recipes. This policy explains what information the app stores and
        how it is used when you sign in or connect external services such as
        Google Calendar or Apple iCloud.
      </p>

      <LegalSection title="Who operates Home Hub">
        <p>
          Home Hub is typically run by a parent or household administrator who
          deploys and maintains the application. That operator controls the
          server, database, and environment configuration for their household.
        </p>
      </LegalSection>

      <LegalSection title="Information we collect">
        <p>
          <strong className="text-[var(--foreground)]">Parent accounts:</strong>{" "}
          name, email address, and authentication credentials managed through
          Better Auth.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">Household data:</strong>{" "}
          household name, timezone, invite code, family profiles (including
          names, colors, birthdays, and optional profile photos), chores,
          routines, meals, and recipes.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">Calendar data:</strong>{" "}
          if you connect Apple Calendar, Home Hub stores your Apple Account
          email and an encrypted app-specific password. If you connect Google
          Calendar, Home Hub stores encrypted OAuth tokens and your Google
          account email. Calendar events synced from connected providers are
          cached so the hub can display and edit them.
        </p>
        <p>
          <strong className="text-[var(--foreground)]">Technical data:</strong>{" "}
          session information, basic request metadata used for security and rate
          limiting, and profile photos stored through Vercel Blob when uploaded.
        </p>
      </LegalSection>

      <LegalSection title="How we use information">
        <p>
          Information is used only to operate the household hub: showing shared
          schedules, managing family tasks and meals, syncing calendars both
          ways, and authenticating parents who manage the household.
        </p>
        <p>
          Home Hub does not sell personal information or use household calendar
          data for advertising.
        </p>
      </LegalSection>

      <LegalSection title="Google Calendar access">
        <p>
          When you choose to connect Google Calendar, Home Hub requests access
          to read and manage calendar events so they can appear on the family
          dashboard and stay in sync with Google. Home Hub also reads your
          Google account email to display which account is connected.
        </p>
        <p>
          You can disconnect Google Calendar at any time from Settings →
          Calendars. Disconnecting removes the stored connection and associated
          synced calendar data from Home Hub.
        </p>
        <p>
          Home Hub&apos;s use of information received from Google APIs follows
          the{" "}
          <a
            href="https://developers.google.com/terms/api-services-user-data-policy"
            className="font-bold text-[var(--sage)]"
            target="_blank"
            rel="noreferrer"
          >
            Google API Services User Data Policy
          </a>
          , including the Limited Use requirements.
        </p>
      </LegalSection>

      <LegalSection title="How information is protected">
        <p>
          Calendar credentials and Google OAuth tokens are encrypted before
          storage. Access to household data is limited to signed-in parents who
          belong to that household. Child profiles do not require their own
          accounts.
        </p>
      </LegalSection>

      <LegalSection title="Data retention and deletion">
        <p>
          Data remains available while your household uses Home Hub. You can
          delete recipes, meals, chores, routines, and profile information
          through the app. Disconnecting a calendar removes that provider&apos;s
          connection and synced events. To remove all household data, contact
          the person who operates your Home Hub deployment.
        </p>
      </LegalSection>

      <LegalSection title="Children">
        <p>
          Home Hub is designed for family use under parent supervision. Children
          are represented as household profiles and do not create separate login
          accounts.
        </p>
      </LegalSection>

      <LegalSection title="Contact">
        <p>
          For privacy questions about a specific Home Hub deployment, contact the
          parent or administrator who runs that instance of the application.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
