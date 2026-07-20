import { createHmac, randomBytes } from "node:crypto";
import { encryptSecret, decryptSecret } from "@/lib/crypto";

const SCOPES = [
  "https://www.googleapis.com/auth/calendar",
  "https://www.googleapis.com/auth/userinfo.email",
];

function canonicalAppUrl() {
  if (process.env.BETTER_AUTH_URL) {
    return process.env.BETTER_AUTH_URL.replace(/\/$/, "");
  }
  if (process.env.NODE_ENV === "development") {
    return "http://localhost:3000";
  }
  throw new Error(
    "BETTER_AUTH_URL must be set to your public app URL (for example https://hobbshomehub.vercel.app).",
  );
}

export function appBaseUrl() {
  return canonicalAppUrl();
}

export function googleOAuthConfig() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri =
    process.env.GOOGLE_REDIRECT_URI ??
    `${canonicalAppUrl()}/api/calendar/google/callback`;
  if (!clientId || !clientSecret) {
    throw new Error("Google Calendar OAuth is not configured.");
  }
  return { clientId, clientSecret, redirectUri };
}

export function googleOAuthState(
  householdId: string,
  options?: { mobile?: boolean },
) {
  const nonce = randomBytes(16).toString("base64url");
  const mobile = options?.mobile ? "1" : "0";
  const payload = `${householdId}.${nonce}.${Date.now()}.${mobile}`;
  const secret = process.env.BETTER_AUTH_SECRET ?? "development";
  const signature = createHmac("sha256", secret)
    .update(payload)
    .digest("base64url");
  return `${payload}.${signature}`;
}

export function verifyGoogleOAuthState(state: string) {
  const parts = state.split(".");
  if (parts.length === 4) {
    const [householdId, nonce, timestamp, signature] = parts;
    const payload = `${householdId}.${nonce}.${timestamp}`;
    const secret = process.env.BETTER_AUTH_SECRET ?? "development";
    const expected = createHmac("sha256", secret)
      .update(payload)
      .digest("base64url");
    if (signature !== expected) throw new Error("Invalid OAuth state.");
    const age = Date.now() - Number(timestamp);
    if (Number.isNaN(age) || age > 10 * 60 * 1000) {
      throw new Error("OAuth state expired.");
    }
    return { householdId: householdId!, mobile: false };
  }
  if (parts.length !== 5) throw new Error("Invalid OAuth state.");
  const [householdId, nonce, timestamp, mobileFlag, signature] = parts;
  const payload = `${householdId}.${nonce}.${timestamp}.${mobileFlag}`;
  const secret = process.env.BETTER_AUTH_SECRET ?? "development";
  const expected = createHmac("sha256", secret)
    .update(payload)
    .digest("base64url");
  if (signature !== expected) throw new Error("Invalid OAuth state.");
  const age = Date.now() - Number(timestamp);
  if (Number.isNaN(age) || age > 10 * 60 * 1000) {
    throw new Error("OAuth state expired.");
  }
  return { householdId: householdId!, mobile: mobileFlag === "1" };
}

export function verifyGoogleOAuthStateSafe(state: string) {
  try {
    return verifyGoogleOAuthState(state);
  } catch {
    return null;
  }
}

export function googleAuthUrl(state: string) {
  const { clientId, redirectUri } = googleOAuthConfig();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: SCOPES.join(" "),
    access_type: "offline",
    prompt: "consent",
    state,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

type TokenResponse = {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  scope?: string;
  token_type: string;
};

export async function exchangeGoogleCode(code: string) {
  const { clientId, clientSecret, redirectUri } = googleOAuthConfig();
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
  });
  if (!response.ok) {
    throw new Error("Google authorization failed.");
  }
  return (await response.json()) as TokenResponse;
}

export async function refreshGoogleAccessToken(refreshToken: string) {
  const { clientId, clientSecret } = googleOAuthConfig();
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      refresh_token: refreshToken,
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
    }),
  });
  if (!response.ok) {
    throw new Error("Google token refresh failed.");
  }
  return (await response.json()) as TokenResponse;
}

export async function fetchGoogleAccountEmail(accessToken: string) {
  const response = await fetch(
    "https://www.googleapis.com/oauth2/v2/userinfo",
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) throw new Error("Could not read Google account.");
  const data = (await response.json()) as { email?: string };
  if (!data.email) throw new Error("Google account email was missing.");
  return data.email;
}

export function storeGoogleTokens(input: {
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
}) {
  const expiresAt = new Date(Date.now() + input.expiresIn * 1000);
  return {
    encryptedAccessToken: encryptSecret(input.accessToken),
    encryptedRefreshToken: input.refreshToken
      ? encryptSecret(input.refreshToken)
      : undefined,
    accessTokenExpiresAt: expiresAt,
  };
}

export function decryptGoogleAccessToken(encrypted: string) {
  return decryptSecret(encrypted);
}

export function decryptGoogleRefreshToken(encrypted: string) {
  return decryptSecret(encrypted);
}
