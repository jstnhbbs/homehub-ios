# Beacon

A family dashboard for native iOS calendars, routines, chores, notes, and weekly meal planning. Beacon is optimized for family iPhone and iPad use, with a web dashboard for shared household management.

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

Beacon does not store calendar provider credentials. Add iCloud, Google, or
other calendar accounts to Apple Calendar on each device, then grant Beacon
calendar access in the iOS app and choose which device calendars to show.

## Turso and Vercel deployment

1. Create a Turso database and token.
2. Set `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` locally, then run `npm run db:migrate`.
3. Import the repository in Vercel.
4. In the Vercel project, create a Blob store and connect it to the project. Vercel adds `BLOB_READ_WRITE_TOKEN` automatically.
5. Add every remaining variable from `.env.example` to Vercel. Set `BETTER_AUTH_URL` and trusted origins to the production HTTPS URL.
6. Deploy.

## Install on iPhone or iPad

Open the deployed site in Safari, tap **Share → Add to Home Screen**, then launch Beacon from its icon. Landscape orientation is recommended for shared iPad display use. Auto-lock behavior is controlled by the device’s Display & Brightness settings.

## Checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run build:with-migrate
npm run test:e2e
```
