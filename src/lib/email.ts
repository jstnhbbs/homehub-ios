export type Email = {
  to: string;
  subject: string;
  text: string;
  html: string;
};

/** What was "sent" when no provider is set up, so tests can read it. Never filled in production. */
export const outbox: Email[] = [];

const RESEND_URL = "https://api.resend.com/emails";

/** Whether `sendEmail` can actually deliver here: a provider is set up, or this isn't production. */
export function canSendEmail() {
  return Boolean(process.env.RESEND_API_KEY && process.env.EMAIL_FROM) || process.env.NODE_ENV !== "production";
}

/**
 * Sends one email through Resend and says whether it was handed over. It never throws: the things
 * that send email (sign-up, "send it again") must not fail because a provider is down or not set up.
 *
 * Production needs `RESEND_API_KEY` and `EMAIL_FROM` (an address on a domain verified with Resend,
 * such as `Beacon <hello@example.com>`). Without them nothing is sent and a warning is logged.
 * Outside production, with no provider, the email goes to the server log instead (and to `outbox`
 * under test), so the verification link can be followed while developing.
 */
export async function sendEmail(email: Email): Promise<boolean> {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.EMAIL_FROM;

  if (!apiKey || !from) {
    if (process.env.NODE_ENV === "production") {
      console.warn("Email not sent: RESEND_API_KEY and EMAIL_FROM are not set.");
      return false;
    }
    outbox.push(email);
    if (process.env.NODE_ENV !== "test") {
      console.info(`[email] to ${email.to}: ${email.subject}\n${email.text}`);
    }
    return true;
  }

  try {
    const response = await fetch(RESEND_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [email.to],
        subject: email.subject,
        text: email.text,
        html: email.html,
      }),
      // A slow provider must not hold up the sign-up that asked for the email.
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) {
      // The status only: the response can echo the address and the message.
      console.error(`Email provider refused the message (status ${response.status}).`);
      return false;
    }
    return true;
  } catch (error) {
    console.error(`Email could not be sent (${error instanceof Error ? error.name : "unknown error"}).`);
    return false;
  }
}
