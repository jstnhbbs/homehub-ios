import type { Email } from "@/lib/email";

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** The page the link in a verification email lands on once the server has checked it. */
export const EMAIL_VERIFIED_PATH = "/email-verified";

/**
 * The verification link Better Auth builds ends at whatever `callbackURL` the sign-up asked for,
 * which for the phone app is nothing at all (the person would see raw JSON or the sign-in page).
 * Point every link at our own "email verified" page instead.
 */
export function verificationLink(url: string) {
  const link = new URL(url);
  link.searchParams.set("callbackURL", EMAIL_VERIFIED_PATH);
  return link.toString();
}

export function verificationEmail(input: { to: string; name: string; url: string }): Email {
  const link = verificationLink(input.url);
  const name = input.name.trim() || "there";
  const text = [
    `Hi ${name},`,
    "",
    "Confirm your email address for Beacon by opening this link:",
    link,
    "",
    "The link works for 24 hours. If you didn't create a Beacon account, you can ignore this email.",
  ].join("\n");
  const html = `<!doctype html>
<html><body style="margin:0;padding:24px;background:#f2f2f7;font-family:-apple-system,Helvetica,Arial,sans-serif;color:#1c1c1e">
<div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:16px;padding:28px">
<h1 style="margin:0 0 12px;font-size:22px">Confirm your email</h1>
<p style="margin:0 0 20px;font-size:16px;line-height:1.5">Hi ${escapeHtml(name)}, confirm your email address for Beacon.</p>
<p style="margin:0 0 24px"><a href="${escapeHtml(link)}" style="display:inline-block;background:#3f8070;color:#ffffff;text-decoration:none;font-weight:600;padding:12px 22px;border-radius:999px">Confirm email</a></p>
<p style="margin:0 0 8px;font-size:13px;color:#6c6c70;line-height:1.5">Or paste this link into your browser:<br><span style="word-break:break-all">${escapeHtml(link)}</span></p>
<p style="margin:16px 0 0;font-size:13px;color:#6c6c70;line-height:1.5">The link works for 24 hours. If you didn't create a Beacon account, you can ignore this email.</p>
</div></body></html>`;
  return { to: input.to, subject: "Confirm your email for Beacon", text, html };
}
