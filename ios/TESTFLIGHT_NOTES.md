# TestFlight notes

Paste the text under "What to Test" into App Store Connect (TestFlight > the build > What to Test). It stays under
TestFlight's 4,000-character limit. It covers everything since build 33; builds 34 to 37 were not sent to testers.

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
