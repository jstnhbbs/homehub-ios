import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { betterAuth } from "better-auth";
import { APIError } from "better-auth/api";
import { db } from "@/db/client";
import * as schema from "@/db/schema";
import {
  AccountDeletionBlockedError,
  detachUserFromHouseholds,
} from "@/lib/account-deletion";

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
    },
  },
  trustedOrigins: process.env.BETTER_AUTH_TRUSTED_ORIGINS?.split(","),
});

export type Session = typeof auth.$Infer.Session;
