import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { betterAuth } from "better-auth";
import { db } from "@/db/client";
import * as schema from "@/db/schema";

export const auth = betterAuth({
  appName: "Home Hub",
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
  emailAndPassword: {
    enabled: true,
    minPasswordLength: 10,
  },
  session: {
    expiresIn: 60 * 60 * 24 * 30,
    updateAge: 60 * 60 * 24,
  },
  rateLimit: {
    enabled: true,
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
