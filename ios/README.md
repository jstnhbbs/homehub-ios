# Home Hub iOS

Native SwiftUI iPad app for Home Hub. It talks to the existing Next.js backend through Better Auth and the `/api/mobile/v1/*` JSON API added for native clients.

## Architecture

```
ios/HomeHub/
├── Models/          # Codable types mirroring src/db/schema.ts
├── Utilities/       # Port of src/lib/* business logic (dates, chores, roles, …)
├── Services/        # Auth + REST API client
├── Views/           # SwiftUI screens matching the web hub
└── App/             # AppState and root navigation
```

The web app remains the source of truth for calendar sync (CalDAV/Google), encrypted credentials, and cron jobs. The iOS app reads cached events and triggers sync via `POST /api/calendar/sync`.

## Prerequisites

1. Xcode 16+ with iOS 17 SDK
2. Running Home Hub backend (`npm run dev` at repo root)
3. Simulator or iPad device on the same network as the API host

## Generate the Xcode project

```bash
cd ios
python3 generate-xcode-project.py
open HomeHub.xcodeproj
```

Re-run the script after adding or removing Swift files.

## Configure API URL

Default: `http://localhost:3000` (set in `HomeHub/Info.plist` as `HOMEHUB_API_URL`).

For a physical iPad pointing at your Mac:

1. Find your Mac's LAN IP (for example `192.168.1.42`).
2. Set `HOMEHUB_API_URL` to `http://192.168.1.42:3000`.
3. Add that origin to `BETTER_AUTH_TRUSTED_ORIGINS` in `.env.local`.

For production, use your deployed HTTPS domain.

## App Transport Security (local dev)

To load `http://` during development, add a temporary ATS exception in Info.plist or use an HTTPS tunnel.

## Feature parity map

| Web (Next.js) | iOS (Swift) |
|---------------|-------------|
| `src/db/schema.ts` | `ios/HomeHub/Models/*` |
| `src/lib/dates.ts`, `chores.ts`, … | `ios/HomeHub/Utilities/*` |
| Server actions | `/api/mobile/v1/*` routes |
| `(hub)/layout.tsx` | `HubView` + sidebar nav |
| `/dashboard` | `DashboardView` |
| `/calendar` | `CalendarView` (read + sync) |
| `/routines`, `/chores`, `/meals`, `/snacks`, `/recipes` | Matching SwiftUI views |
| `/settings` | `SettingsView` |

## What's implemented vs. next steps

**Done in this translation**

- Data models for all major entities
- Business logic utilities ported from TypeScript
- Auth (sign in / sign up / session restore via Better Auth cookies)
- Household onboarding (create / join / guest join)
- Dashboard with schedule, routines, chores, meals, **snacks** (checklist + parent snack list editing)
- **Full calendar**: month/week/day views, agenda, search, event CRUD, Apple/Google connect, calendar selection, week start, auto-sync
- **Routines**: checklist cards by period, daily step check-offs, add/edit/delete (parents)
- **Chores**: grouped by family profile, cadence-aware check-offs, add/edit/delete (parents)
- **Meals**: weekly grid, recipe picker, copy/clear week (parents)
- **Recipes**: card grid, import URL, add/edit/delete (parents)
- **Profiles**: family member CRUD in Settings (parents); **Profile** tab for account + self-edit (all members, including guests)
- **Settings**: household members list with guest removal (parents)
- **Profile photos**: pick from library, upload, replace, remove (parents for any profile; guests for own)
- Mobile REST API under `src/app/api/mobile/v1/`

**Still to build in Swift**

- Offline cache (SwiftData)
- Push notifications

## Run checks

Backend:

```bash
npm run typecheck
npm run lint
```

iOS (after opening in Xcode): **Product → Build** (⌘B), then run on iPad simulator in landscape.
