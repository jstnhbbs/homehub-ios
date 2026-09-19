import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/legal-page";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Beacon collects, uses, and protects family data.",
};

export default function PrivacyPolicyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="July 15, 2026">
      <p>
        Beacon is a family dashboard for calendars, routines, chores, meals,
        and recipes. This policy explains what information the app stores and
        how it is used when you sign in or grant device permissions.
      </p>

      <LegalSection title="Who operates Beacon">
        <p>
          Beacon is typically run by a parent or household administrator who
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
          Beacon reads calendar events from the calendars available on your
          iPhone or iPad after you grant iOS calendar permission. Beacon does
          not store Apple, Google, or other calendar-provider credentials.
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
          schedules, managing family tasks and meals, and authenticating
          parents who manage the household.
        </p>
        <p>
          Beacon does not sell personal information or use household calendar
          data for advertising.
        </p>
      </LegalSection>

      <LegalSection title="How information is protected">
        <p>
          Access to household data is limited to signed-in parents who belong
          to that household. Child profiles do not require their own accounts.
        </p>
      </LegalSection>

      <LegalSection title="Data retention and deletion">
        <p>
          Data remains available while your household uses Beacon. You can
          delete recipes, meals, chores, routines, and profile information
          through the app. Owners and parents can save a JSON copy of their
          household data from Settings. You can delete your account at any time
          from the Profile screen in the app. If you are the only member of a
          household, deleting your account also permanently deletes that
          household and everything in it. If others share the household, you
          leave it and your profile is removed; the household&apos;s only owner
          must first make another member an owner.
        </p>
      </LegalSection>

      <LegalSection title="Children">
        <p>
          Beacon is designed for family use under parent supervision. Children
          are represented as household profiles and do not create separate login
          accounts.
        </p>
      </LegalSection>

      <LegalSection title="Contact">
        <p>
          For privacy questions about a specific Beacon deployment, contact the
          parent or administrator who runs that instance of the application.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
