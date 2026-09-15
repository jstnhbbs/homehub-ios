import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/legal-page";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "Terms for using the Beacon family dashboard.",
};

export default function TermsOfServicePage() {
  return (
    <LegalPage title="Terms of Service" updated="July 15, 2026">
      <p>
        These Terms of Service govern your use of Beacon. By creating a parent
        account or joining a household, you agree to these terms.
      </p>

      <LegalSection title="The service">
        <p>
          Beacon provides a shared family dashboard for calendars, routines,
          chores, meals, and recipes. Features may change as the application is
          updated.
        </p>
      </LegalSection>

      <LegalSection title="Eligibility and accounts">
        <p>
          Beacon is intended for parents or guardians managing a household.
          You are responsible for keeping your sign-in credentials secure and
          for activity that occurs through your account.
        </p>
        <p>
          You may invite another parent to your household using the household
          invite code. Do not share invite codes publicly.
        </p>
      </LegalSection>

      <LegalSection title="Device permissions">
        <p>
          If you grant calendar access on iPhone or iPad, you authorize Beacon
          to read calendar data available on that device. You are responsible
          for ensuring you have the right to show any calendar content inside
          the household app.
        </p>
      </LegalSection>

      <LegalSection title="Acceptable use">
        <p>You agree not to misuse Beacon, including by:</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>attempting to access another household&apos;s data</li>
          <li>interfering with the security or operation of the service</li>
          <li>using the service for unlawful purposes</li>
        </ul>
      </LegalSection>

      <LegalSection title="Your content">
        <p>
          You retain responsibility for the information you add to Beacon,
          including family profile details, calendar events, recipes, and meal
          plans. You grant Beacon permission to store and process that
          information solely to provide the service to your household.
        </p>
      </LegalSection>

      <LegalSection title="Availability and changes">
        <p>
          Beacon is provided on an as-available basis. The operator of your
          deployment may perform maintenance, updates, or configuration changes
          that temporarily affect availability.
        </p>
        <p>
          These terms may be updated from time to time. Continued use of Home
          Hub after updates become effective constitutes acceptance of the
          revised terms.
        </p>
      </LegalSection>

      <LegalSection title="Disclaimer">
        <p>
          Beacon is provided without warranties of any kind, to the fullest
          extent permitted by law. Calendar sync, reminders, and household
          planning features should not be relied on as your only source of
          time-sensitive scheduling information.
        </p>
      </LegalSection>

      <LegalSection title="Limitation of liability">
        <p>
          To the fullest extent permitted by law, Beacon and its operator
          will not be liable for indirect, incidental, special, consequential,
          or punitive damages arising from your use of the service.
        </p>
      </LegalSection>

      <LegalSection title="Contact">
        <p>
          For questions about these terms, contact the parent or administrator
          who operates your Beacon deployment.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
