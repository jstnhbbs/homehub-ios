# Home Hub

An iPad-first family dashboard for Apple and Google calendars, routines, chores, and weekly meal planning.

## Stack

- Next.js App Router, React, TypeScript, and Tailwind CSS
- Turso/libSQL with Drizzle ORM
- Better Auth for parent accounts
- Apple iCloud CalDAV and Google Calendar OAuth for private, two-way sync
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

## Connect calendars

### Apple Calendar

iCloud does not provide Calendar OAuth. Each household must create an app-specific password:

1. Enable two-factor authentication for the Apple Account.
2. Visit [account.apple.com](https://account.apple.com), then open **Sign-In and Security → App-Specific Passwords**.
3. Create a password named “Home Hub.”
4. In Home Hub, open **Settings → Calendars** and connect Apple Calendar with the account email and generated password.

The app-specific password is encrypted with AES-256-GCM before it is stored. Never use or paste the primary Apple Account password.

### Google Calendar

1. Create a Google Cloud project and enable the Google Calendar API.
2. Configure an OAuth client (Web application) with redirect URI `https://your-domain/api/calendar/google/callback` (or `http://localhost:3000/api/calendar/google/callback` locally).
3. On the OAuth consent screen, set:
   - **Application home page:** `https://your-domain`
   - **Privacy policy:** `https://your-domain/privacy`
   - **Terms of service:** `https://your-domain/terms`
4. Add `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` to your environment.
5. In Home Hub, open **Settings → Calendars** and click **Connect Google Calendar**.

Refresh tokens are encrypted with the same `CALENDAR_ENCRYPTION_KEY` used for Apple credentials. A household can connect both Apple and Google at the same time.

## Turso and Vercel deployment

1. Create a Turso database and token.
2. Set `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` locally, then run `npm run db:migrate`.
3. Import the repository in Vercel.
4. In the Vercel project, create a Blob store and connect it to the project. Vercel adds `BLOB_READ_WRITE_TOKEN` automatically.
5. Add every remaining variable from `.env.example` to Vercel. Set `BETTER_AUTH_URL` and trusted origins to the production HTTPS URL.
6. Deploy. The daily cron works on Vercel Hobby; an active wall display also requests a freshness-limited sync every five minutes.

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
