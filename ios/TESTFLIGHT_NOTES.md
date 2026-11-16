# TestFlight notes

Paste the text under "What to Test" into App Store Connect (TestFlight > the build > What to Test). It stays under
TestFlight's 4,000-character limit. Build 38 notes cover everything since build 33; builds 34 to 37 were not sent to testers.

## Build 39 (version 2026.11)

Build 38 (2026.10.1) already went to external testers, so these notes cover what changed since it.

### What to Test

Thanks for testing Tugboat! This build fixes things found after build 38 and makes some screens a little quicker.

WEEKLY PLAN AND RECIPES
- Close a recipe you opened from a meal and you now go back to where you were: the Weekly Plan or Today, not the Recipes list.
- The book icon on Today's Food card no longer covers long dish names.
- A recipe that is no longer available closes itself instead of leaving a blank sheet.
- On a wide phone, Edit and More in the Weekly Plan's bar should each appear once.

SPEED
- Date labels in the Weekly Plan, Calendar and week headers should draw a little faster, and loading lists of items does less work.

Please try:
1. Food > Weekly Plan > tap a meal with a book icon, then close it. You should land back on the plan.
2. Do the same from Today's Food card. You should land back on Today.
3. Tap Edit, change a meal, tap Done.

Please tell us about anything that sticks, overlaps or can't be closed, and which device and orientation you used.

### Changes in build 39 (for the developer)

- Closing a recipe returns to the page it was opened from (`AppState.recipeReturn`).
- Blank recipe sheet dismisses itself; recipe icon no longer overlaps meal names; Edit and More bar items attach once.
- Meal tap rules have a check (`ios/checks/meal-tap`).
- Speed: week days cached, shared date formatters and calendars, no `String(format:)` in local dates, one shared ISO formatter when decoding.

## Build 38 (version 2026.10.1)

### What to Test

Thanks for testing Tugboat! This build covers everything new since build 33. The biggest changes are the meal plan
and how the app looks on foldable and wide phones.

MEAL PLAN
- The Weekly Plan now has an Edit button. Until you tap Edit, it is read-only, so scrolling can't move or clear a meal.
- Tap a meal that came from a saved recipe and the recipe opens. A book icon marks those meals.
- Tap Edit to add or change meals, swipe to clear or copy to tomorrow, or press and hold to drag a meal to another
  slot. Tap Done when you finish. Copy Last Week and Clear Week are in the More menu while you are editing.
- On Today, tonight's dinner and the meal tiles in the Food card open their saved recipe too.
- A recipe that opens as a sheet now has a close button.

TODAY
- The Large Snacks card now shows the snack options themselves, as many across as fit, instead of the "0 of 11 eaten"
  count.

FOLDABLE AND WIDE PHONES (iPhone Duo and similar)
- Wide phones use the system tab bar (a vertical bar at the side when the phone is held a certain way) instead of the
  iPad sidebar.
- Pages sit inside the safe areas, with the page title and main button (Add Chore, Add Recipe, and so on) in the
  navigation bar.
- Snacks stays clear of the side bar, Food opens with its week arrows visible, and recipe cards say "Serves 4".

Please try on any device:
1. Open Food > Weekly Plan, tap Edit, add a meal, tap Done, then tap a meal with a recipe.
2. From Today, tap tonight's dinner in the Food card.
3. Open Snacks from Today, then get back to Today.
4. Turn the phone or unfold it, if you can, and look for text running under the tab bar or cut off.

Please tell us about anything that sticks, overlaps, or can't be closed, and which device and orientation you used.

### Changes since build 33 (for the developer)

- 34: wide phone layouts follow Apple's iPhone Duo guidance (safe areas and size classes, no window measurements).
- 35: wide phone pages use a navigation bar for the title and main action.
- 36: archived with Xcode 27.1 so the system can place bars vertically on iPhone Duo.
- 37: Snacks list stays inside the side bar's safe area, Food opens with its week header visible, recipe cards label
  servings.
- 38: Weekly Plan Edit mode; meals open their saved recipe (Weekly Plan and Today's Food card); recipe sheet close
  button; Large Snacks card shows snack options instead of a count.
