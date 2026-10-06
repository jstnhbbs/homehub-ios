"use client";

import { MailWarning } from "lucide-react";
import { useState } from "react";
import { authClient } from "@/lib/auth-client";

/** Shown to someone whose email address is not confirmed yet. They can still use the app. */
export function VerifyEmailNotice({ email }: { email: string }) {
  const [state, setState] = useState<"idle" | "sending" | "sent" | "failed">("idle");

  async function send() {
    setState("sending");
    const { error } = await authClient.sendVerificationEmail({
      email,
      callbackURL: "/email-verified",
    });
    setState(error ? "failed" : "sent");
  }

  return (
    <div
      role="status"
      className="mt-4 flex flex-wrap items-center gap-3 rounded-2xl border border-[var(--line)] bg-[var(--tile)] p-4 text-sm"
    >
      <MailWarning size={20} className="shrink-0 text-[var(--sage)]" />
      <p className="min-w-0 flex-1 leading-6">
        {state === "sent"
          ? `We sent a confirmation link to ${email}. It works for 24 hours.`
          : state === "failed"
            ? "We couldn’t send that just now. Wait a minute and try again."
            : `Your email address (${email}) isn’t confirmed yet.`}
      </p>
      {state !== "sent" ? (
        <button
          type="button"
          className="hub-button secondary"
          disabled={state === "sending"}
          onClick={send}
        >
          {state === "sending" ? "Sending…" : "Send confirmation email"}
        </button>
      ) : null}
    </div>
  );
}
