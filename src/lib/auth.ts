import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { betterAuth } from "better-auth";
import { APIError } from "better-auth/api";
import { db } from "@/db/client";
import * as schema from "@/db/schema";
import {
  AccountDeletionBlockedError,
  detachUserFromHouseholds,
} from "@/lib/account-deletion";
import { sendEmail } from "@/lib/email";
import { verificationEmail } from "@/lib/email-templates";

export const auth = betterAuth({
  appName: "Beacon",
  secret:
    process.env.BETTER_AUTH_SECRET ??
    (process.env.NODE_ENV === "development"
      ? "development-only-home-hub-secret-change-me"
      : undefined),
  baseURL: process.env.BETTER_AUTH_URL,
  database: drizzleAdapter(db, {
    provider: "sqlite",
    schema,
    usePlural: true,
  }),
  user: {
    changeEmail: {
      enabled: true,
      updateEmailWithoutVerification:
        process.env.NODE_ENV === "development",
    },
    // Requires the account password. beforeDelete can veto (sole owner of a shared household)
    // and removes the user's household data before the user record itself goes.
    deleteUser: {
      enabled: true,
      beforeDelete: async (user) => {
        try {
          await detachUserFromHouseholds(user.id);
        } catch (error) {
          if (error instanceof AccountDeletionBlockedError) {
            throw new APIError("BAD_REQUEST", { message: error.message });
          }
          throw error;
        }
      },
    },
  },
  emailAndPassword: {
    enabled: true,
    minPasswordLength: 10,
    // Deliberately not required: an unverified address can still sign in and use the app (they are
    // reminded to confirm it). Requiring it would lock out every account made before this existed,
    // and anyone whose email is slow or never arrives.
  },
  emailVerification: {
    sendOnSignUp: true,
    // Following the link confirms the address and nothing else. Signing the browser in as well
    // would make the email link a login, usable by anyone who sees it.
    autoSignInAfterVerification: false,
    expiresIn: 60 * 60 * 24,
    sendVerificationEmail: async ({ user, url }) => {
      // sendEmail never throws, so a provider problem cannot fail a sign-up.
      await sendEmail(verificationEmail({ to: user.email, name: user.name, url }));
    },
  },
  session: {
    expiresIn: 60 * 60 * 24 * 30,
    updateAge: 60 * 60 * 24,
  },
  rateLimit: {
    enabled: process.env.DISABLE_AUTH_RATE_LIMIT !== "true",
    storage: "database",
    window: 60,
    max: 100,
    customRules: {
      "/sign-in/email": { window: 60, max: 5 },
      "/sign-up/email": { window: 60, max: 3 },
      // "Send it again" must not be a way to flood someone's inbox.
      "/send-verification-email": { window: 60, max: 2 },
    },
  },
  trustedOrigins: process.env.BETTER_AUTH_TRUSTED_ORIGINS?.split(","),
});

export type Session = typeof auth.$Infer.Session;
