<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Project map

Beacon is a family household dashboard (routines, chores, meals/recipes, groceries, sleep logs, birthdays, notes, calendar, weather). It is **iOS-first**: the SwiftUI app in `ios/` is the product, and the Next.js app is its backend plus a thin web shell.

- **Backend** (`src/`): Next.js 16 App Router, Drizzle on Turso/libSQL (`src/db/schema.ts`), Better Auth (`src/lib/auth.ts`). Roles are `owner`, `parent`, `guest` (`src/lib/household-roles.ts`).
- **Mobile API** (`src/app/api/mobile/v1/*`): one route folder per module. Routes use the helpers in `src/lib/mobile/http.ts` (`requireMobileHousehold`, `requireMobileParentHousehold`, `handleMobileError`). `src/lib/mobile/dashboard.ts` builds the dashboard payload.
- **Guest permissions:** guests are "view and log", enforced on the server and covered by `src/lib/guest-permissions.test.ts` (it calls every mobile route as owner, parent, guest, and signed-out). Setup and shared data are parent-only via `requireMobileParentHousehold`. Guests can read everything, add a note (`POST /notes`), log activity (naps, routine step and chore and snack check-offs), edit their own profile and photo, and change their own layout preferences. Editing or deleting notes and every grocery change are parent-only. The iOS views hide controls with `appState.canManageHousehold`, but the server is the enforcement point. When you add a mobile route, add it to the test table.
- **Account deletion** goes through Better Auth's `deleteUser` (enabled in `src/lib/auth.ts`, wrapped by `DELETE /api/mobile/v1/account`). Its `beforeDelete` hook runs `detachUserFromHouseholds` (`src/lib/account-deletion.ts`), which blocks the only owner of a shared household and deletes or leaves households otherwise. The privacy page describes this, so keep them in sync.
- **Routine streaks** are computed on the server (`src/lib/streaks.ts` for the rules, `src/lib/streak-store.ts` to load them) and returned as `routineStreaks` in the dashboard payload; the iOS app only displays them and celebrates milestones. Steps carry a `created_at` so adding a step never erases an existing streak; older steps fall back to their first completion.
- **Who completed what:** routine and chore completions record `completed_by` (the user who checked it off). The dashboard and chores payloads return `completedAt` and `completedByName`; it is null for older completions and after that person deletes their account (foreign key `ON DELETE SET NULL`). The household export leaves it out.
- **Recipe tags** are a JSON array in `recipes.tags`. `src/lib/recipes/tags.ts` normalizes them (preset spelling, dedupe, limits) and suggests them from a page's category and the ingredients; the iOS copy of the rules is `RecipeTagHelpers.swift`, so change both together. Updating a recipe without a `tags` field leaves its tags alone, so older app versions do not erase them.
- **Web** (`src/app/`): every `(hub)/*` page except `settings` is an `IOSOnlyPage` stub. Real web pages are sign-in, onboarding, settings (household, profiles, members, photos), privacy, and terms. Server actions in `src/app/actions.ts` cover only household, profile, and photo management.
- **iOS** (`ios/HomeHub/`): `Models` mirror the schema, `Utilities` port logic from `src/lib`, `Services` hold the API client and on-device integrations (EventKit calendars, Reminders for groceries, WeatherKit, local notifications), `ViewModels` and `Views` are per module. There is also a widget under `ios/HomeHubWidget/`. The Xcode project is generated: after adding or removing Swift files, run `python3 ios/generate-xcode-project.py`. See `ios/README.md`.
- **Calendars are on-device only.** The server stores no calendar credentials or events. Anything named `calendarConnections`, `calendars`, or `calendarEvents` in the schema is unused legacy.
- **Schema changes:** hand-write the SQL in `drizzle/NNNN_name.sql` and add its entry to `drizzle/meta/_journal.json` (with a `when` greater than the previous one). Do not run `db:generate`: snapshots stop at 0007, so it would emit a bogus diff. Every statement in a file needs `--> statement-breakpoint` between it and the next, or only the first statement runs. `vercel.json` runs `db:migrate` before the build for production deploys only (`VERCEL_ENV=production`), so previews never touch the database. Migrations are the only way the schema changes: there is no runtime patching. `node scripts/check-migrations.mjs` (read-only) shows what `db:migrate` would run against `TURSO_DATABASE_URL`.

Checks: `npm run typecheck`, `npm run lint`, `npm test`, and an Xcode build of the `HomeHub` scheme for any iOS change.

## Cursor Cloud specific instructions

Standard commands live in `package.json` and `README.md` ("Checks" section); the notes below only cover non-obvious setup for running the backend in this VM.

- `.env.local` is gitignored, so it does not persist across fresh VMs. Create it before running the dev server: `cp .env.example .env.local`. `TURSO_DATABASE_URL` defaults to `file:local.db` and `BETTER_AUTH_SECRET` has a dev fallback, so the app boots even with empty secrets, but a real `.env.local` avoids surprises.
- The local SQLite DB (`local.db`) is gitignored and not created by `npm install`. Run `npm run db:migrate` once before `npm run dev` (migrations are intentionally kept out of the startup update script).
- Run the dev server with `npm run dev` (Turbopack) on port 3000. Do not use `npm start` for development. `npm run build:with-migrate` runs `db:migrate` first; plain `npm run build` does not.
- E2E tests (`npm run test:e2e`) use Playwright and need browsers installed first (`npx playwright install`, and `npx playwright install-deps` if system libs are missing). The Playwright config auto-starts its own dev server against `file:e2e.db`, so no manual server is needed for e2e.
- Core hello-world flow: open `http://localhost:3000` → Sign in → "Create an account" → complete `/onboarding` by creating a household → lands on `/settings`. Vercel Blob photo upload is an optional integration needing external credentials and is not required for local core testing.
