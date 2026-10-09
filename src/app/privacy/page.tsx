import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/legal-page";
import { APP_NAME, CONTACT_EMAIL } from "@/lib/app-info";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: `How ${APP_NAME} collects, uses, and protects family data.`,
};

const strong = "text-[var(--foreground)]";

export default function PrivacyPolicyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="October 8, 2026">
      <p>
        {APP_NAME} is a family dashboard for routines, chores, meals, recipes,
        groceries, notes, sleep logs, birthdays, and the day&apos;s schedule and
        weather. This policy explains what information the app stores, what stays
        on your device, who else handles it, and how you can delete it.
      </p>

      <LegalSection title="Who we are">
        <p>
          {APP_NAME} is made and run by Justin Hobbs, an individual developer.
          Questions about this policy or your data can go to{" "}
          <a className="font-bold text-[var(--sage)]" href={`mailto:${CONTACT_EMAIL}`}>
            {CONTACT_EMAIL}
          </a>
          .
        </p>
      </LegalSection>

      <LegalSection title="Information we store">
        <p>
          <strong className={strong}>Your account:</strong> your name, email
          address, and a password (kept only as a one-way hash, so nobody,
          including us, can read it). We use your email address to sign you in
          and to send a one-time link that confirms the address is yours. We do
          not send marketing email.
        </p>
        <p>
          <strong className={strong}>Your household:</strong> the household name
          and time zone, invite codes, and what your family adds: profiles
          (names, colors, birthdays, and optional photos), birthdays and
          anniversaries, chores, routines and when each step was done and by
          whom, snacks, meals and recipes (including recipes you import from a
          web address or a Crouton file), grocery items (unless you use Reminders), notes, and nap and
          sleep logs. Parents may enter details about children, such as a name,
          a birthday, and sleep times.
        </p>
        <p>
          <strong className={strong}>Photos:</strong> you choose a photo with the
          system photo picker, so {APP_NAME} sees only the photos you pick. Photos
          for profiles, the family, and recipes are stored with our storage
          provider. Each has a long web address that cannot be guessed, but
          anyone who has the exact address can open it, so do not add photos you
          would not want shared.
        </p>
        <p>
          <strong className={strong}>Technical data:</strong> a session that
          keeps you signed in (stored in the iOS Keychain on your device), and
          basic request details, including your IP address, used briefly for
          security and to limit repeated attempts. Our hosting provider also
          keeps ordinary server logs.
        </p>
      </LegalSection>

      <LegalSection title="What stays on your device">
        <p>
          <strong className={strong}>Calendars:</strong> {APP_NAME} reads events
          from the calendars on your iPhone or iPad after you allow access. They
          are shown on your device and are not sent to our servers. We never
          receive your Apple, Google, or other calendar sign-in details.
        </p>
        <p>
          <strong className={strong}>Reminders:</strong> if you allow access and
          choose a list, grocery items you add are written to that list in the
          Reminders app on your device (and shared by Apple if the list is
          shared), not stored on our servers. Without Reminders access, items are
          kept in {APP_NAME}&apos;s own grocery list on our servers.
        </p>
        <p>
          <strong className={strong}>Notifications:</strong> reminders for
          routines, chores, naps, and birthdays are scheduled on your device.
          {" "}{APP_NAME} does not use a push notification server.
        </p>
        <p>
          <strong className={strong}>A saved copy:</strong> so the app opens
          without a connection, it keeps a protected copy of your household
          information on the device. It is left out of device backups.
        </p>
      </LegalSection>

      <LegalSection title="Weather and location">
        <p>
          If you allow location access, {APP_NAME} uses your device&apos;s
          approximate location to ask Apple Weather for local conditions. The
          location goes to Apple for that request; it is not sent to our servers
          and we do not store it. Weather is provided by Apple Weather; see{" "}
          <a
            className="font-bold text-[var(--sage)]"
            href="https://developer.apple.com/weatherkit/data-source-attribution/"
          >
            Apple&apos;s data sources
          </a>
          .
        </p>
      </LegalSection>

      <LegalSection title="Who else handles your information">
        <p>
          We use a few providers to run the service, and each handles only what
          its job needs: Vercel hosts the app and stores photos, Turso hosts the
          database, Resend delivers the confirmation emails, and Apple provides
          weather. We do not sell personal information, do not show advertising,
          and do not track you across other apps or websites. There are no
          analytics or advertising tools in {APP_NAME}.
        </p>
      </LegalSection>

      <LegalSection title="Who can see household information">
        <p>
          Everyone in a household can see that household&apos;s information.
          Parents and owners can change it and manage members; guests can view it
          and log activity such as naps and check-offs. Invite codes control who
          can join, so keep them private. Your household&apos;s information is
          never shown to other households.
        </p>
      </LegalSection>

      <LegalSection title="Keeping and deleting your information">
        <p>
          Your information is kept while you use {APP_NAME}. You can delete
          recipes, meals, chores, routines, notes, and profiles in the app, and a
          photo is removed from storage when you replace it, remove it, or delete
          what it belongs to. Owners and parents can save a copy of their
          household information from Settings.
        </p>
        <p>
          You can delete your account at any time from Settings → Account in the app. If you
          are the only member of a household, this permanently deletes the
          household and everything in it, including its photos. If others share
          the household, you leave it and your profile is removed; the
          household&apos;s only owner must first make another member an owner.
        </p>
      </LegalSection>

      <LegalSection title="Children">
        <p>
          {APP_NAME} is for parents and guardians. Children appear only as
          profiles that a parent creates and do not have accounts. We do not
          knowingly collect information directly from children. A parent can
          delete a child&apos;s profile and logs at any time, or ask us to at the
          address below.
        </p>
      </LegalSection>

      <LegalSection title="Changes to this policy">
        <p>
          If we change what we collect or how we use it, we will update this
          page and its date.
        </p>
      </LegalSection>

      <LegalSection title="Contact">
        <p>
          Write to{" "}
          <a className="font-bold text-[var(--sage)]" href={`mailto:${CONTACT_EMAIL}`}>
            {CONTACT_EMAIL}
          </a>{" "}
          with any question about your information or to ask us to delete it.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
