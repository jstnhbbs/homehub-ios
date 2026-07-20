import { NextResponse } from "next/server";
import { connectGoogleCalendar } from "@/lib/google/calendar";
import { appBaseUrl, verifyGoogleOAuthState, verifyGoogleOAuthStateSafe } from "@/lib/google/oauth";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const error = url.searchParams.get("error");
  const base = appBaseUrl();

  if (error || !code || !state) {
    const mobile = state ? verifyGoogleOAuthStateSafe(state)?.mobile : false;
    if (mobile) {
      return NextResponse.redirect(
        new URL("homehub://calendar-oauth?error=google-auth-denied", base),
      );
    }
    return NextResponse.redirect(
      new URL("/settings/calendar?error=google-auth-denied", base),
    );
  }

  try {
    const { householdId, mobile } = verifyGoogleOAuthState(state);
    await connectGoogleCalendar({ householdId, code });
    if (mobile) {
      return NextResponse.redirect(
        new URL("homehub://calendar-oauth?connected=google", base),
      );
    }
    return NextResponse.redirect(
      new URL("/settings/calendar?connected=google", base),
    );
  } catch {
    const mobile = verifyGoogleOAuthStateSafe(state)?.mobile;
    if (mobile) {
      return NextResponse.redirect(
        new URL("homehub://calendar-oauth?error=google-connect-failed", base),
      );
    }
    return NextResponse.redirect(
      new URL("/settings/calendar?error=google-connect-failed", base),
    );
  }
}
