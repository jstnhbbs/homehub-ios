# Beacon iOS

Native SwiftUI app for Beacon on iPhone and iPad. It talks to the existing Next.js backend through Better Auth and the `/api/mobile/v1/*` JSON API added for native clients, so edits made on a parent phone use the same household data that appears on the larger shared display.

## Architecture

```
ios/HomeHub/
├── Models/          # Codable types mirroring src/db/schema.ts
├── Utilities/       # Port of src/lib/* business logic (dates, chores, roles, …)
├── Services/        # Auth + REST API client
├── Views/           # SwiftUI screens matching the web hub
└── App/             # AppState and root navigation
```

The web app remains the source of truth for household data, routines, chores, meals, recipes, and profiles. The iOS app reads calendars through native EventKit access only; any iCloud or Google calendars should be added to Apple Calendar on the device, then selected inside Beacon.

## Prerequisites

1. Xcode 16+ with iOS 17 SDK
2. Running Beacon backend (`npm run dev` at repo root)
3. Simulator or iPhone/iPad device on the same network as the API host

## Generate the Xcode project

```bash
cd ios
python3 generate-xcode-project.py
open HomeHub.xcodeproj
```

Re-run the script after adding or removing Swift files.

## Configure API URL

Default: `https://hobbshomehub.vercel.app` (set in `HomeHub/Info.plist` as `HOMEHUB_API_URL`).

For a physical iPhone or iPad pointing at your Mac:

1. Find your Mac's LAN IP (for example `192.168.1.42`).
2. Set `HOMEHUB_API_URL` to `http://192.168.1.42:3000`.
3. Add that origin to `BETTER_AUTH_TRUSTED_ORIGINS` in `.env.local`.

For another production deployment, use that HTTPS domain.

## App Transport Security (local dev)

To load `http://` during development, add a temporary ATS exception in Info.plist or use an HTTPS tunnel.

## Feature parity map

| Web (Next.js) | iOS (Swift) |
|---------------|-------------|
| `src/db/schema.ts` | `ios/HomeHub/Models/*` |
| `src/lib/dates.ts`, `chores.ts`, … | `ios/HomeHub/Utilities/*` |
| Server actions | `/api/mobile/v1/*` routes |
| `(hub)/layout.tsx` | `HubView` + adaptive sidebar/tab navigation |
| `/dashboard` | `DashboardView` (includes nap quick log) |
| `/naps` | `NapsView` (sheet from dashboard; not in sidebar) |
| `/calendar` | `CalendarView` (native calendar read + local calendar selection) |
| `/routines`, `/chores`, `/meals` (weekly plan + recipes), `/snacks` | Matching SwiftUI views |
| `/groceries`, `/birthdays`, `/notes` | `GroceriesView`, `BirthdaysView`, `NotesView` |
| `/settings` | `SettingsView` |

## What's implemented vs. next steps

**Done in this translation**

- Data models for all major entities
- Business logic utilities ported from TypeScript
- Auth (sign in / sign up / session restore via Better Auth cookies)
- Household onboarding (create / join / guest join)
- Dashboard with schedule, routines, chores, meals, **snacks** (checklist + parent snack list editing)
- **Calendar** (read-only): month/week/day views, agenda, search, native EventKit access, local calendar selection, week start
- **Groceries** (synced with Apple Reminders), **Birthdays**, and pinned household **Notes**
- **Routines**: checklist cards by period, daily step check-offs, add/edit/delete (parents)
- **Chores**: grouped by family profile, cadence-aware check-offs, add/edit/delete (parents)
- **Meals**: week navigation, a day-by-day list on iPhone and a grid on iPad, tap-a-slot picker (saved recipes, recently used, custom text), automatic saving, swipe/context-menu/drag-and-drop to clear, copy, and move meals, copy/clear week, and "Add Week to Groceries" (parents). It merges the rest of the week's recipe ingredients into a preview, sums amounts only when units match, and adds the chosen items to Reminders or the household list.
- **Recipes**: card grid, import URL, add/edit/delete (parents)
- **Profiles**: family member CRUD in Settings (parents); **Profile** tab for account + self-edit (all members, including guests)
- **Settings**: household members list with guest removal (parents), household data export to Files (parents)
- **Account deletion** (Profile → Delete Account, password required): a sole member's household is deleted with them, the only owner of a shared household must transfer ownership first, and anyone else just leaves
- **Profile photos**: pick from library, upload, replace, remove (parents for any profile; guests for own)
- Local snapshot cache for the last household/dashboard load
- Local notifications for routines, chores, and sleep reminders
- Per-user hub module toggles, sidebar order, and dashboard card order and size
- Mobile REST API under `src/app/api/mobile/v1/`
- Adaptive iPhone layouts for parent editing flows, with the same backend data refreshing on larger display clients.

**Still to build in Swift**

- Widget target integration: `HomeHubWidget/` exists but the generated Xcode project has only the `HomeHub` app target
- Creating and editing calendar events (the server-side event API was removed; the "default calendar for new events" setting is currently unused)

## Run checks

Backend:

```bash
npm run typecheck
npm run lint
```

Ingredient parsing and merging (used by "Add Week to Groceries") has standalone checks that need only the Swift toolchain:

```bash
ios/checks/ingredient-merge/run.sh
```

iOS (after opening in Xcode): **Product → Build** (⌘B), then run on iPhone and iPad simulators. Landscape remains recommended for a dedicated shared iPad display.
