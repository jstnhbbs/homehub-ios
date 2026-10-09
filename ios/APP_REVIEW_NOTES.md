# App Review notes

Paste the text below into App Store Connect: the app's **App Review Information** for the first build
(TestFlight beta review uses the same fields), with the two sign-ins filled in. Never commit the
passwords. To create or refresh the demo accounts and their data, run `npm run seed:demo` (see the top of
`scripts/seed-demo.ts`); run it again shortly before submitting, because the data is dated relative to
the day it runs.

---

**Sign-in is required.** Use either demo account (both are already set up with a made-up family):

- Parent (owner) account: `<owner email>` / `<owner password>`
- Guest account: `<guest email>` / `<guest password>`

**What the app is.** A shared dashboard for a family household: routines, chores, meals and recipes,
groceries, notes, sleep logs, birthdays and anniversaries, with the day's schedule and weather. Tabs along
the bottom open the main pages; More has the rest and Settings.

**What to look at.**
- Today: cards for the schedule, routines (with a streak), chores, meals, snacks, sleep and groceries.
  Tap a routine step or a chore to check it off. Tap the weather for its details.
- Food: the weekly plan, a recipe library with tags, and snacks. Open a recipe to see sections and nutrition.
- Sleep: start a nap or log past sleep for a child. Starting a nap shows a Live Activity on the Lock Screen
  and in the Dynamic Island.
- Groceries, Notes, Routines, Chores and Celebrations (birthdays and anniversaries) each have sample data.
- Settings: appearance (light, dark and true black, ten theme colors and app icons), notifications,
  layout, family members and invite codes, and a data export.

**Parent and guest.** The parent account can edit everything. The guest account can view everything and log
activity (naps, check-offs, notes) but cannot edit or delete shared data, and does not see invite codes.

**Permissions (all optional; the app works without them).**
- Calendars: the Schedule card shows events from the calendars on the device. The review device probably has
  none, so add an event for today in the Calendar app to see it.
- Reminders: Groceries can write to a shared list in Reminders instead of the app's own list.
- Location (when in use): approximate location is sent to Apple Weather to show local weather. Weather is
  provided by Apple WeatherKit.
- Notifications: reminders for routines, chores, naps and birthdays are scheduled on the device.

**Account deletion.** Settings → Account → Delete Account. The parent demo account is the only member of its
household, so deleting it works and removes its household. (If you delete it, we recreate it.)

**Other.** No in-app purchases, no ads, no tracking, no third-party sign-in. Photos are chosen with the system
photo picker. Privacy policy: https://hobbshomehub.vercel.app/privacy
