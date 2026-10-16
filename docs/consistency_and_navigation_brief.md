# Consistency and navigation update: implementation brief

Read `AGENTS.md` first. This is one completed app update: bump the patch
version and build number once in `pubspec.yaml` and report the result. Do items
in the order given; item 1 is a correctness bug and must not be skipped.

## 1. Walking time differs between screens (bug)

Same stage, same saved pace, three different results:

- Today shows Stage 1a (24.6 km) as "6 h 46 m".
- Explore and Map show it as "8 hr 53 min walking".
- Plan days work out at roughly 3.1 km/h effective speed (22.42 km in 7 hr 11).

With the user's saved flat pace of 3.2 km/h, Explore (about 2.8 km/h effective
on a big climb) and the plan (about 3.1 km/h) are plausible. Today (about 3.6
km/h effective, faster than the flat pace) is the wrong one.

Cause found in the code:

- `lib/ui/home_screen.dart` (~line 462): when there is no plan day, the Walking
  time tile uses the stored `recent!.timeMinutes` from the stage record. It
  ignores the saved pace. It also formats with its own `shortTime`.
- `lib/ui/stage_list_screen.dart` (~line 325) and `lib/ui/screens.dart`
  (~line 336) compute time with `WalkingTime.estimate(weightedDistance,
  settings.paceKmh)` and format with `WalkingTime.format`.

Required:

1. Add one shared helper (for example `Future<Duration?> stageWalkingTime(
   Stage, CaminoRepository, SettingsService)`) that sums the route weights and
   calls `WalkingTime.estimate`, as `StageListScreen` does. Use it on Today,
   Explore, Map chooser and stage detail.
2. Remove the `timeMinutes` fallback on Today. If weights are unavailable show
   "Walking time unavailable", the same wording as the stage detail screen.
3. Use `WalkingTime.format` everywhere. Delete `shortTime` or make it call
   `WalkingTime.format`. Also check `navigation_summary.dart` (~line 119),
   which formats hours and minutes separately.
4. Distance precision: use one decimal ("22.4 km") on every screen, including
   plan day cards (`camino_plan_screen.dart` ~line 579, `walking_day_screen.dart`
   ~line 620). Leave the PDF as it is unless it is easy to match.
5. Add a test: change the pace in settings, then assert Today and Explore show
   the same duration string for the same stage, and that it changes with pace.
   Do not delete or relax existing tests.

## 2. Map tab should open the map, not a second stage list

The Map tab currently shows the same list as Explore (same search, chips,
banner, cards), titled "Choose a stage map".

- Tapping Map opens the map for the current stage straight away (the stage Today
  shows; if none, the first stage).
- Add a "Change stage" button on the map screen that opens the existing chooser.
- Explore stays the single place for browsing and searching stages.
- Keep each tab's own navigation stack (`persistent_tabs.dart`).
- Update tests that assume the Map tab opens a list.

## 3. Explore and chooser list cleanup (`stage_list_screen.dart`)

- Use one term for the current stage: "Selected stage" (Today already says "Your
  selected stage"). Replace "Last opened" and "Continue here".
- Remove the full-width "Continue here: ..." banner above the list (the
  highlighted card is the same stage), or shrink it to "Continue: Stage 1a".
- Put the "Route choice" chip on the same row as the stage number so cards are
  shorter.
- Turn the note "Walking estimates use your saved flat-ground pace." into one
  line with a tappable "Change" that opens Settings.
- Selected filter chip (All, Planned, Route choices): use
  `colorScheme.primaryContainer` with `caminoYellow` label and check, matching
  the selected nav tab.
- Screen title: "Stages" on the Explore tab is fine; make the tab label and the
  title match if cheap.

## 4. Plan screen polish (`camino_plan_screen.dart`)

- Journey summary: show the three key numbers as tiles like Today (days, km,
  walking time) instead of five lines of text. Under them one status line, for
  example "All 5 nights have a stay. 0 booked."
- Use the same stay status words everywhere. The summary says "Considering" but
  the day card chip says "Planned"; pick one set and use it in both.
- Put 12 dp between "Add a day" and "Share plan PDF" (they currently touch).
- Share appears twice (app bar icon and button). Keep the button, remove the
  app bar icon.
- Group edit and delete in an overflow menu, and make sure delete asks for
  confirmation before removing the plan.
- Day card: change "Depart 08:00 | Arrive approximately 16:11" (it wraps badly)
  to "08:00 to about 16:11" on one line, and give distance and time the same
  emphasis as the Today metric tiles.

## 5. Settings screen (`lib/ui/settings_screen.dart`)

- Group the controls in cards with small gold section labels ("Walking speed",
  "Off-route alerts", "About"), matching the card style used on the Plan screen.
- Save automatically when a slider is released (`onChangeEnd`) and show a short
  "Saved" confirmation (a check and the word, for about 2 seconds). Remove the
  "Save pace" and "Save alert distance" buttons. Keep a test that the value is
  persisted and reloaded.
- Give both sliders the same style: solid track, no dotted tick marks or stray
  notch at the left end, a visible thumb, and min and max labels (for the pace,
  "Relaxed 2.0" and "Brisk 7.0").
- Use "walking speed" everywhere (Settings, Explore note, Plan, Map). Do not
  use "pace".
- Replace the pace description with: "Times use your flat-ground speed and
  adjust for climbs and descents. Breaks are not included."
- Replace the long alerts paragraph with three short lines: alerts are off
  until you start a walking session from a stage map; continuous GPS can drain
  the battery, so start with enough charge and stop the session when you finish;
  force-closing the app stops tracking. Move the remaining detail behind a
  "Location and privacy" row that opens a detail page or an expandable section.
- Move "Version 0.3.35 - Build 141" to a small "About" row at the bottom.

## 6. Launch colour and first-run Today

- Native launch background: `android/app/src/main/res/drawable/launch_background.xml`
  is plain white and `drawable-v21/launch_background.xml` uses the system
  background, so a light flash can appear before the in-app splash. Add
  `<color name="camino_launch">#0F2438</color>` (the new `caminoBlue`) in
  `values/colors.xml` and use it as the background in both drawables. For
  Android 12 and later also set `android:windowSplashScreenBackground` to the
  same colour in `values-v31/styles.xml` (and `values-night-v31` if it exists).
  Do the equivalent for iOS in `LaunchScreen.storyboard` if it is not already
  navy. Make no other changes to the splash.
- The app launches on Today after the splash. When there is no selected stage
  and no plan (first run), show a short welcome card on Today instead of an
  empty stage card: "Plan your Camino", with "Choose a starting stage" as the
  main button and "Just browse the stages" as a text button. Hide it once a
  stage has been selected or a plan exists. Use existing strings and styles;
  keep it to one card, no new screens.

## Checks

`dart format .`, `flutter analyze` and `flutter test` must all pass. Fix tests
that assert changed copy or layout; do not delete or skip any. Check on a
360 x 740 dp screen at default and 1.3x text. Report files changed and the new
version and build number.
