# Home Screen Widgets

The existing `HomeHubLiveActivity` WidgetKit extension now contains Sleep Live
Activity plus nine Home Screen widgets: Up Next, Child's Routines, Chores,
Tonight's Dinner, Sleep, Household Note, Groceries, Celebrations and Household
Snapshot. Snapshot supports medium and large; the others support small, medium
and large. iOS 17 or later is required.

## Device Signing

Both the app and extension use the App Group `group.com.porchlighthome.app`.
Register/enable this group for both bundle IDs in the developer team's App Groups
capability and regenerate provisioning profiles if Xcode requests it. Automatic
signing may manage this. The generator preserves these entitlements.

The extension does **not** share the sign-in Keychain. Interactive actions use
`LiveActivityIntent` to run in the main app process, where credentials already
live. The extension's copy of the intent refuses execution rather than silently
pretending that a write succeeded.

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
uses the active sleep ID. The runner verifies the current user and household,
fetches fresh data, checks membership and the household's current day, then writes.
An active sleep can end across midnight; old daily check-offs cannot.

Failed writes keep data intact and publish a visible widget error. A failed
follow-up read after a successful write does not undo the known successful result.
An expired sign-in clears credentials and widget content. A session change during
an action or photo fetch cannot republish the previous account's snapshot.

Tapping summary content opens a whitelisted `tugboat://widget/<destination>` deep
link. Dinner can carry one validated recipe UUID to open its saved recipe;
unknown routes and other query parameters are ignored. Hidden sections follow the
app's navigation preferences rather than bypassing them.

## Checks

`ios/checks/widgets/run.sh` covers timezone rollover, selection, past events,
snapshot persistence/coalescing/clearing, deep links, stale actions and account
boundaries. The simulator gallery, child selection, background refresh and
Routines deep link were checked without writing household check-offs.
End-to-end write actions still need a physical
device or disposable household test; they were not exercised on the real family.

For installation: launch and sign in once, then Home Screen > Edit > Add Widget >
Tugboat. The in-app Settings FAQ includes widget instructions and update limits.
