# Porchlight

A family dashboard for native iOS calendars, routines, chores, notes, and weekly meal planning. Porchlight is optimized for family iPhone and iPad use, with a web dashboard for shared household management.

## Stack

- Next.js App Router, React, TypeScript, and Tailwind CSS
- Turso/libSQL with Drizzle ORM
- Better Auth for parent accounts
- Native iOS EventKit calendar access in the iPhone/iPad app
- Vercel Blob for child profile photos
- Vitest and Playwright

## Local setup

1. Install dependencies and create the environment file:

   ```bash
   npm install
   cp .env.example .env.local
   ```

2. Fill the secrets in `.env.local`. Generate independent values with `openssl rand -base64 32`.

3. Create the local database and run the app:

   ```bash
   npm run db:migrate
   npm run dev
   ```

Open `http://localhost:3000`, create a parent account, then create or join a household.

## Calendars

Porchlight does not store calendar provider credentials. Add iCloud, Google, or
other calendar accounts to Apple Calendar on each device, then grant Porchlight
calendar access in the iOS app and choose which device calendars to show.

## Turso and Vercel deployment

1. Create a Turso database and token.
2. Set `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` locally, then run `npm run db:migrate`.
3. Import the repository in Vercel.
4. In the Vercel project, create a Blob store and connect it to the project. Vercel adds `BLOB_READ_WRITE_TOKEN` automatically.
5. Add every remaining variable from `.env.example` to Vercel. Set `BETTER_AUTH_URL` and trusted origins to the production HTTPS URL.
6. Deploy. `vercel.json` runs `npm run db:migrate` before the build for production deployments only, so `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` must be set for the Production environment. Preview deployments skip migrations.

To see what a migration run would do against a database without changing it, run `node scripts/check-migrations.mjs` with `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` set.

## Install on iPhone or iPad

Install the native app through Xcode or TestFlight. See [the iOS setup guide](ios/README.md) for build and backend configuration. The website provides account and household management; the family dashboard runs in the native app.

## Backups and data export

- **Email confirmation:** a new account is emailed a one-time link (valid 24 hours) that confirms its address. An unconfirmed address can still sign in and use everything; the app and the web settings page remind them and offer to send it again. Email goes out through Resend: set `RESEND_API_KEY` and `EMAIL_FROM` (an address on a domain you have verified with Resend) in the deployment's environment. Without them production sends nothing (and logs a warning), and development prints the email, including the link, in the server log.
- **Household export:** owners and parents can save a JSON copy of their household from the iOS app (Settings → General → Export Household Data). It leaves out invite codes and member email addresses.
- **Database backup:** for a full copy of the production database, run this while signed in to the Turso CLI:

  ```bash
  mkdir -p backups && turso db shell homehub .dump > backups/homehub-$(date +%F).sql
  ```

  The `backups/` folder is gitignored. A dump contains password hashes and session tokens, so keep it private. To restore into a new database: `turso db create homehub-restored --from-dump backups/<file>.sql`.
- **Point-in-time restore:** Turso can restore a database to an earlier moment, but how far back depends on your plan. Check the Turso dashboard for your window, and note that delete protection is enabled on the production database, so removing it requires running `turso db config delete-protection disable homehub` first.

## Checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run build:with-migrate
npm run test:e2e
```
