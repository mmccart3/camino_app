# Today screen and navigation polish: implementation brief

Small, visual-only update after the palette refresh. Do not change behaviour,
routes, data or copy other than what is listed. Read `AGENTS.md` first. This is
one completed app update: bump the patch version and build number once in
`pubspec.yaml` and report the new values.

## 1. Selected tab is too faint (`lib/ui/app_theme.dart`)

`buildCaminoTheme()` has no `navigationBarTheme`, so the bar uses Material
defaults and the selected tab is a dark blue pill with a white label. Add:

```dart
navigationBarTheme: NavigationBarThemeData(
  height: 76,
  backgroundColor: colorScheme.surfaceContainerLow,
  surfaceTintColor: Colors.transparent,
  indicatorColor: colorScheme.primaryContainer, // 0xFF4A3A12
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
    color: states.contains(WidgetState.selected)
        ? caminoYellow
        : colorScheme.onSurfaceVariant,
  )),
  labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
    fontSize: 12,
    fontWeight: states.contains(WidgetState.selected)
        ? FontWeight.w700
        : FontWeight.w600,
    color: states.contains(WidgetState.selected)
        ? caminoYellow
        : colorScheme.onSurfaceVariant,
  )),
),
```

The bar is built in `lib/ui/persistent_tabs.dart` (line ~98). Do not hard-code
colours there. Check that "My Camino" still fits on one line on a 360 dp wide
screen with large system text; if it does not, shorten the label spacing before
shortening the word.

## 2. Today header takes too much height (`lib/ui/home_screen.dart`, ~line 365)

Currently: app bar title, then a row with `AppLogo(size: 56)`, "Today" and the
italic tagline, then the date on its own line. The card is pushed below the
fold and its GPS row sits under the nav.

- Remove the `AppLogo` from this row (the app bar title already carries the
  brand).
- Put "Today" and the date together: headline "Today", with the formatted date
  directly under it in `onSurfaceVariant`. Remove the separate date line and
  the `SizedBox(height: 16)` after it.
- Keep "One step at a time." only for the empty state, not on every visit.
- Reduce the outer padding from 20 to 16 horizontally and 12 vertically at the
  top.

Goal: on a 360 x 740 dp screen the full stage card, including the GPS row and
the Update button, is visible without scrolling, above the nav bar.

## 3. Secondary action buttons are cramped (`home_screen.dart`, ~line 513)

The Ahead, Elevation and Diary buttons use horizontal padding 4, so
"Elevation" touches its border.

- Horizontal padding 4 -> 8, vertical 12 -> 10.
- Gap between buttons 6 -> 8.
- Icon size 22.
- Wrap each label in `FittedBox(fit: BoxFit.scaleDown, child: Text(...))` so it
  shrinks instead of clipping at large text sizes.
- Apply the same changes to `TodayDiaryButton(compact: true)` so all three
  match.
- Keep minimum tap height at 48 dp.

## 4. GPS state is easy to miss (`lib/ui/today_progress.dart`, ~line 175)

The icon already uses `CaminoColors.gpsGood` and `gpsStale`. Also colour the
label text the same way when stale (use `CaminoColors.of(context).gpsStale`),
and keep it `onSurface` when fresh. Do not change the wording or the 120 second
threshold. Keep "Update" as it is.

## Checks

- `dart format .`, `flutter analyze`, `flutter test` must all pass. Fix any test
  that asserts removed layout (for example the tagline or the logo on Today);
  do not delete or skip tests.
- Look at Today on a 360 x 740 dp emulator at default and at 1.3x text size and
  confirm nothing is clipped or overflowing.
- Report the files changed and the new version and build number.
