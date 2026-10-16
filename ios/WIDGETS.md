# Home Screen Widgets

The existing `TugboatLiveActivity` WidgetKit extension now contains Sleep Live
Activity plus nine Home Screen widgets: Up Next, Child's Routines, Chores,
Tonight's Dinner, Sleep, Household Note, Groceries, Celebrations and Household
Snapshot. Snapshot supports medium and large; the others support small, medium
and large. iOS 17 or later is required.

## Device Signing

Both the app and extension use the App Group `group.com.tugboatfamily.app`.
Register/enable this group for both bundle IDs in the developer team's App Groups
capability and regenerate provisioning profiles if Xcode requests it. Automatic
signing may manage this. The generator preserves these entitlements.

The app and the extension share the sign-in through the Keychain access group
`$(AppIdentifierPrefix)com.tugboatfamily.app` (the `keychain-access-groups`
entitlement on both targets; it is the group the app's own item already lives in,
so nobody is signed out). The extension never uses `SessionCredentials.shared(for:)`,
because that runs the app's first-launch migration, which would clear a session it
can't find in the extension's own defaults; it builds `SessionCredentials(baseURL:)`.

Check-off circles and End Sleep (`HouseholdWidgetActionIntent`) are plain `AppIntent`s
that **run in the extension** (`WidgetWriter`). A `LiveActivityIntent` runs in the app's
process, and iOS then waited about three seconds before redrawing the widget that was
tapped (measured: the action finished in 6 ms and the redraw came 3.15 s later, whether
or not the server work had finished). In the extension the redraw follows in about
0.1 s. The tap checks the saved snapshot, shows the change from it (`appliedEarly`),
returns, and the write goes to the server behind it (`writeRequest`, the same routes
and bodies as the app, always saying `completed: true`). If the write fails the one
item is put back (`reverted`) and the error shows in the footer. Reloading only the
affected kinds (`affectedKinds`) matters: `reloadAllTimelines()` redraws every widget
one after another. The server a snapshot may send a sign-in to is `serverURL` (https,
or localhost while developing); a snapshot from before `server` existed asks for the
app to be opened. The widget leaves a timestamp and a Darwin notification
(`WidgetWriteSignal`) after a successful write; the app listens (`WidgetWriteObserver`)
and also checks when it comes to the front (`AppState.refreshForWidgetWrites`), then
reloads the dashboard and bumps `externalChangeToken`, which the Chores, Sleep and
Routines pages watch. Rows that copy "done" into `@State` must follow their data with
`.onChange` (they didn't, which hid widget changes). The Refresh button
(`HouseholdWidgetRefreshIntent`) is still a `LiveActivityIntent` because it rebuilds the
whole snapshot (calendar, reminders, server data) in the app (`WidgetActionRunner`).
To measure widget timing again, log timestamps from the intent, the provider and the
view body into `<App Group>/Library/` (only Library, Documents and tmp can be copied
off a device with `devicectl device copy from --domain-type appGroupDataContainer`).

## Data and Updates

- `WidgetSnapshotBuilder` exports display data only, not the full dashboard or
  household object. There are no credentials, emails, or invite codes in it.
- `WidgetStore` writes one atomically replaced JSON file in the App Group with
  protection until the device's first unlock after reboot. Sign-out removes it.
- AppState publishes a debounced snapshot after dashboard, device calendar,
  grocery-list, layout, or theme updates. Equal automatic refreshes are coalesced;
  the timestamp advances at least on fifteen-minute checks while the app refreshes.
- Widgets read this local snapshot. They do not poll the backend in their timeline
  providers. Opening/refreshing Tugboat or tapping a widget's refresh arrow fetches
  new household data. iOS controls redraw timing; there is no guaranteed live feed.
- Providers include calendar boundaries and household midnight in timelines.
  Yesterday's routines, chores, meals and overview are replaced by a refresh state.
- Calendar events and Reminders groceries are device-local and use this device's
  existing permissions and selected lists. Widgets never prompt for access.
- Dinner photos are fetched during timeline creation, downsampled, and checked
  against the latest account snapshot before returning. Other widgets don't fetch
  the dinner photo.

## Actions and Configuration

Every widget has two appearance choices in Edit Widget: **Accent Color** (Same as App, or any of the
ten theme colors by name) and **True Black** (a black background in dark mode; light mode stays white
and dark mode is otherwise the app's charcoal). Same as App follows the theme chosen in Settings >
Appearance, which the app writes into the snapshot whenever it changes. The accent is lightened or
deepened to read on the widget's own background, as in the app (`ColorMath.textShade`).

Routines and Notes use App Intent configuration. Child selection includes shared
routine steps; selecting no child shows everyone. Selecting no note favors pinned
notes. A deleted selected child/note is not silently replaced with another one.

Routine and chore circles send `completed: true`, never toggle blindly. End Sleep
uses the active sleep ID. The widget verifies the current user and household, the item
and the household's current day against the saved snapshot (`WidgetActionPolicy`), then
shows the change and writes; the server enforces who may do what. An active sleep can
end across midnight; old daily check-offs cannot.

A failed write puts the one item back and publishes a visible widget error, keeping
anything newer in the snapshot. The Refresh button (app-run) rebuilds the snapshot
from fresh server data, calendar and reminders. An expired sign-in clears credentials
and widget content when the app notices it. A session change during an action or photo
fetch cannot republish the previous account's snapshot.

Tapping summary content opens a whitelisted `tugboat://widget/<destination>` deep
link. Dinner can carry one validated recipe UUID to open its saved recipe;
unknown routes and other query parameters are ignored. Hidden sections follow the
app's navigation preferences rather than bypassing them.

## Checks

`ios/checks/widgets/run.sh` covers timezone rollover, selection, past events,
snapshot persistence/coalescing/clearing, deep links, stale actions and account
boundaries. The simulator gallery, child selection, background refresh and
Routines deep link were checked without writing household check-offs.
The write actions were exercised on a real iPhone on 2026-10-15 (End Sleep, a chore and a
routine step: each redraws at once, reaches the server and shows in the app). The checks
also cover early updates and putting them back, the request each tap sends, which widget
kinds reload, and which servers a snapshot may send a sign-in to.

For installation: launch and sign in once, then Home Screen > Edit > Add Widget >
Tugboat. The in-app Settings FAQ includes widget instructions and update limits.
