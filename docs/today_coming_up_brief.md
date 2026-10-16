# Today: "Coming up" card (next cafe, pharmacy and shop)

Read `AGENTS.md` first. This is one completed app update: bump the patch
version and build number once in `pubspec.yaml` and report the result.

## Goal

A walker should see, without opening anything, where the next cafe or bar,
pharmacy and grocery shop are on today's route, with distance and walking time.
The Ahead screen already knows this; Today should surface it.

## What already exists (reuse it, add no new data)

- `AheadOfMeService().calculate(route, nearestIndex, paceKmh)` in
  `lib/services/ahead_of_me.dart` returns the places ahead in order, each with
  `location`, `metres` and `walkingTime`.
- `Location.hasBarCafe`, `hasPharmacy` and `hasGroceryStore` are the only
  service flags in the data. There is no water flag; do not show water.
- `AheadScreen` already works out the nearest track point from a position, and
  has a "Preview from stage start" mode (index 0).
- `TodayProgress` (`lib/ui/today_progress.dart`) does the explicit foreground
  position check and never starts tracking. Keep it that way.
- Walking time must use `WalkingTime.format` and the saved speed
  (`settings.paceKmh`), as on the other screens. Distances: one decimal ("2.1 km").

## What to build

1. A pure helper in `lib/services/`, for example `NextServices`:
   `NextServices.from(List<AheadPlace> ahead)` returning the first place with
   `hasBarCafe == true`, the first with `hasPharmacy == true` and the first with
   `hasGroceryStore == true` (each nullable). Only `true` counts; `null` and
   `false` do not.
2. A "Coming up" card on Today (new widget in its own file, for example
   `lib/ui/coming_up_card.dart`), placed directly under the stage card and above
   "Tonight". Up to three rows, in this order: cafe or bar, pharmacy, shop. Each
   row shows a coloured icon chip, the place name, and "2.1 km · 38 min".
   - Chip: 32 dp rounded square, 1.5 dp white border, white Material icon
     (`local_cafe`, `local_pharmacy`, `shopping_basket`). Fill colours match the
     new map icons: cafe `#A85A00`, pharmacy `#1E8A47`, shop `#7A4FA3`. Add them
     to `CaminoColors` as `serviceEat`, `servicePharmacy` and `serviceShop`
     rather than hard-coding them in the card.
   - Row height at least 48 dp. The whole row is tappable.
3. Which position to use:
   - After the user has pressed Update (a GPS fix exists), use the nearest
     track point, the same way `AheadScreen` does, and label the card
     "Coming up on your route".
   - Before any fix, use the start of the stage (index 0) and label the card
     "Along today's route". Do not request location automatically.
   - Recompute only when the user updates GPS, or the stage, plan day or walking
     speed changes. Do not poll.
4. Empty and gap states (important for planning food and water):
   - If no place ahead has a given service, show the row greyed with "None
     recorded before <stage end name>". Use the words "recorded", because the
     flags are unknown (`null`) for many locations.
   - If all three are missing, show one line: "Nothing recorded for the rest of
     this stage. Carry food and water."
5. Tapping a row opens `AheadScreen` for the same stage with the matching filter
   already selected (Café, Pharmacy, or the groceries filter if there is one).
   Add an optional `initialFilter` parameter to `AheadScreen`; the default stays
   'All'. A small "See all ahead" text button at the bottom of the card opens it
   unfiltered.
6. For a plan day that spans a different route than the selected stage, use the
   same route source `TodayProgress.update()` uses (`day.guidancePoints`, else the
   stage route). If `AheadOfMeService` cannot be used for that route (for
   example `route.canGuide` is false), hide the card rather than show wrong
   distances.
7. Loading and errors: load the route after the first frame and show nothing
   (no spinner, no error banner) until it is ready. If it fails, hide the card.
   Cache per stage so returning to Today does not reload the route.

## Tests

- Unit: `NextServices.from` picks the first of each service, ignores `null` and
  `false`, and returns all-null for an empty list.
- Widget: Today for Stage 1 shows "Along today's route" with at least one row
  and the same walking-time text as the Ahead screen for the same place; after a
  simulated position update it shows "Coming up on your route".
- Widget: a route with no flagged places shows the "Carry food and water" line.
- Changing the walking speed in settings changes the times shown.
- Do not delete or skip existing tests.

## Checks

`dart format .`, `flutter analyze` and `flutter test` must all pass. Check on a
360 x 740 dp screen at default and 1.3x text: the stage card, GPS row and the
first "Coming up" rows should be visible without a long scroll, and nothing
should overflow. Report files changed and the new version and build number.
