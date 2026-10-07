# Beacon iOS

Native SwiftUI app for Beacon on iPhone and iPad. It talks to the existing Next.js backend through Better Auth and the `/api/mobile/v1/*` JSON API added for native clients, so edits made on a parent's phone show up on the family iPad and the other way round.

## Architecture

```
ios/HomeHub/
├── Models/          # Codable types mirroring src/db/schema.ts
├── Utilities/       # Port of src/lib/* business logic (dates, chores, roles, …)
├── Services/        # Auth + REST API client
├── Views/           # SwiftUI screens, one folder per module
└── App/             # AppState and root navigation
```

The Next.js server in the repo root is the source of truth for household data, routines, chores, meals, recipes, and profiles. Its own web pages are only sign-in, onboarding, a settings page and the legal pages; everything else is this app. The iOS app reads calendars through native EventKit access only; any iCloud or Google calendars should be added to Apple Calendar on the device, then selected inside Beacon.

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

## Where things live

| Server (`src/`) | iOS (`ios/HomeHub/`) |
|-----------------|----------------------|
| `db/schema.ts` | `Models/*` |
| `lib/*` business rules (dates, chores, streaks, tags, …) | `Utilities/*` (the rules the app needs on the device) |
| `app/api/mobile/v1/*` | `Services/HomeHubAPI.swift` |
| Today | `DashboardView`, with the sleep quick log |
| Calendar | `CalendarView` (reads the device's calendars through EventKit) |
| Routines, Chores, Food (weekly plan, snacks, recipes), Sleep | `RoutinesView`, `ChoresView`, `MealsView` / `SnacksView` / `RecipesView`, `NapsView` |
| Groceries, Birthdays, Notes | `GroceriesView`, `BirthdaysView`, `NotesView` |
| Settings | `SettingsView` |
| Navigation shell | `HubView`: tab bar on iPhone, sidebar on iPad |

## What's implemented vs. next steps

**Implemented**

- Data models for all major entities
- Business logic utilities ported from TypeScript
- Auth (sign in / sign up / session restore via Better Auth cookies)
- Household onboarding (create / join / guest join)
- Dashboard with schedule, routines, chores, meals, **snacks** (checklist + parent snack list editing)
- **Calendar** (read-only): month/week/day views, agenda, search, native EventKit access, local calendar selection, week start
- **Groceries** (synced with Apple Reminders), **Birthdays** (and anniversaries), and pinned household **Notes**. Entries can be birthdays or anniversaries; anniversaries count years instead of an age and are added by hand (a profile's own birthday stays a birthday). The module reads **Birthdays** until the household has an anniversary and **Celebrations** after that, decided by the server's `hasAnniversaries` flag so it doesn't depend on what's coming up soon. On someone's birthday or anniversary the Today screen shows a banner (photo, "Happy birthday, Emma!", "Turning 6 today") with a short confetti burst once that day, and the Birthdays card highlights them. It follows the household's date, so it appears at midnight without a refresh, and it respects the Birthdays module toggle and Reduce Motion
- **Routines**: checklist cards by period, daily step check-offs, add/edit/delete (parents), and **streaks**: a flame badge with the days in a row a child finished every step, and a once-a-day banner at 3, 7, 14, 30, 50, 100, 200, and 365 days
- **Chores**: grouped by family profile, cadence-aware check-offs, add/edit/delete (parents). Completed chores show who checked them off and when, and routines list what was done today the same way
- **Meals**: week navigation, a day-by-day list on iPhone and a grid on iPad, tap-a-slot picker (saved recipes, recently used, custom text), automatic saving, swipe/context-menu/drag-and-drop to clear, copy, and move meals, copy/clear week, and "Add Week to Groceries" (parents). It merges the rest of the week's recipe ingredients into a preview, sums amounts only when units match, and adds the chosen items to Reminders or the household list.
- **Recipes**: card grid, import URL, add/edit/delete (parents), and **tags**: meal types (Breakfast, Lunch, Dinner, Snack, Dessert), proteins (Chicken, Beef, Pork, Turkey, Fish, Seafood, Vegetarian), and your own. Imports suggest tags from the page's category and the ingredients, filter chips narrow the list (Dinner + Chicken), and the meal planner shows recipes tagged for the slot first
- **Profiles**: family member CRUD in Settings (parents); **Profile** tab for account + self-edit (all members, including guests)
- **Settings**: household members list with guest removal (parents), household data export to Files (parents)
- **Account deletion** (Profile → Delete Account, password required): a sole member's household is deleted with them, the only owner of a shared household must transfer ownership first, and anyone else just leaves
- **Profile photos**: pick from library, upload, replace, remove (parents for any profile; guests for own)
- Local snapshot cache for the last household/dashboard load
- Local notifications for routines, chores, sleep, and **birthdays**. Birthday reminders are chosen in Settings → Notifications: on the day, and any of 1 day, 3 days, 1 week, or 2 weeks before, at a time you pick (8:00 AM by default) in the household's time zone. They are planned up to 45 days ahead so they arrive even if the app isn't opened, capped at 30 to leave room for the other reminders
- Sleep Live Activity: while a child is napping or in bed, the lock screen and Dynamic Island show a running timer (`HomeHubLiveActivity/`, started and ended by `SleepLiveActivityManager`). It is started locally, so it needs no push entitlement; it appears on a device when the app next refreshes, and iOS ends any Live Activity after about 8 hours
- Per-user hub module toggles, sidebar order, and dashboard card order and size
- Mobile REST API under `src/app/api/mobile/v1/`
- Adaptive layouts: phone, and iPad with side panels that appear only when the window is wide enough (Groceries, Recipes, Snacks, Meals, Birthdays).

**Still to build in Swift**

- A home-screen widget. An earlier draft was removed because it could never run: it needs an App Group to share data with the app, which a Personal Team can't provision. It is in git history (the `HomeHubWidget/` folder before the commit that removed it) if that changes. The generated project has the `HomeHub` app and the `HomeHubLiveActivity` extension (sleep Live Activity) only
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
ios/checks/meal-plan/run.sh
ios/checks/streak-helpers/run.sh
ios/checks/completion-helpers/run.sh
ios/checks/recipe-tags/run.sh
ios/checks/birthday-today/run.sh
ios/checks/birthday-notifications/run.sh
ios/checks/meal-slot-clock/run.sh
ios/checks/celebration-text/run.sh
ios/checks/dashboard-row-helpers/run.sh
sh ios/checks/async-lifecycle/run.sh
ios/checks/notification-diff/run.sh
```

iOS (after opening in Xcode): **Product → Build** (⌘B), then run on iPhone and iPad simulators. Landscape remains recommended for a dedicated shared iPad display.
