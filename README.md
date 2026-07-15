# Home Hub

An iPad-first family dashboard for Apple calendars, routines, chores, and weekly meal planning.

## Stack

- Next.js App Router, React, TypeScript, and Tailwind CSS
- Turso/libSQL with Drizzle ORM
- Better Auth for parent accounts
- iCloud CalDAV for private, two-way calendar sync
- Vitest and Playwright

## Local setup

1. Install dependencies and create the environment file:

   ```bash
   npm install
   cp .env.example .env.local
   ```

2. Fill the three secrets in `.env.local`. Generate independent values with `openssl rand -base64 32`.

3. Create the local database and run the app:

   ```bash
   npm run db:migrate
   npm run dev
   ```

Open `http://localhost:3000`, create a parent account, then create or join a household.

## Connect Apple Calendar

iCloud does not provide Calendar OAuth. Each household must create an app-specific password:

1. Enable two-factor authentication for the Apple Account.
2. Visit [account.apple.com](https://account.apple.com), then open **Sign-In and Security → App-Specific Passwords**.
3. Create a password named “Home Hub.”
4. In Home Hub, open **Settings → Apple Calendar** and enter the Apple Account email and generated password.

The app-specific password is encrypted with AES-256-GCM before it is stored. Never use or paste the primary Apple Account password.

## Turso and Vercel deployment

1. Create a Turso database and token.
2. Set `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` locally, then run `npm run db:migrate`.
3. Import the repository in Vercel.
4. Add every variable from `.env.example` to Vercel. Set `BETTER_AUTH_URL` and trusted origins to the production HTTPS URL.
5. Deploy. The daily cron works on Vercel Hobby; an active wall display also requests a freshness-limited sync every five minutes.

`CALENDAR_ENCRYPTION_KEY` must remain stable after calendars are connected. Changing it makes saved credentials unreadable.

## Install on iPad

Open the deployed site in Safari, tap **Share → Add to Home Screen**, then launch Home Hub from its icon. Landscape orientation is recommended. Auto-lock behavior is controlled by the iPad’s Display & Brightness settings.

## Checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run test:e2e
```
