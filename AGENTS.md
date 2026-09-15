<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Cursor Cloud specific instructions

Beacon is a single Next.js 16 (App Router) app backed by libSQL/SQLite. Standard commands live in `package.json` and `README.md` ("Checks" section); the notes below only cover non-obvious setup for running it in this VM.

- `.env.local` is gitignored, so it does not persist across fresh VMs. Create it before running the dev server: `cp .env.example .env.local`. `TURSO_DATABASE_URL` defaults to `file:local.db` and `BETTER_AUTH_SECRET`/`CALENDAR_ENCRYPTION_KEY` have dev fallbacks, so the app boots even with empty secrets, but a real `.env.local` avoids surprises.
- The local SQLite DB (`local.db`) is gitignored and not created by `npm install`. Run `npm run db:migrate` once before `npm run dev` (migrations are intentionally kept out of the startup update script).
- Run the dev server with `npm run dev` (Turbopack) on port 3000. Do not use `npm run build`/`npm start` for development — `npm run build` also re-runs `db:migrate`.
- E2E tests (`npm run test:e2e`) use Playwright and need browsers installed first (`npx playwright install`, and `npx playwright install-deps` if system libs are missing). The Playwright config auto-starts its own dev server against `file:e2e.db`, so no manual server is needed for e2e.
- Core hello-world flow: open `http://localhost:3000` → Sign in → "Create an account" → complete `/onboarding` by creating a household → lands on `/dashboard`. Calendar (Apple/Google), Vercel Blob photo upload, and cron sync are optional integrations needing external credentials and are not required for local core testing.
