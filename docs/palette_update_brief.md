# Palette refresh: implementation brief

Goal: keep the navy-and-gold identity but use softer, more consistent shades, and stop hard-coding colours in screens. This is a colour change only. Do not change layouts, copy, behaviour or navigation.

Read `AGENTS.md` first. This counts as a completed app update, so bump the patch version and build number once in `pubspec.yaml` and report the result.

## 1. Brand constants

`lib/ui/app_title.dart`

| Constant | Old | New |
|---|---|---|
| `caminoYellow` | `0xFFE5A93C` | `0xFFE8B04A` |
| `caminoBlue` | `0xFF0D1F33` | `0xFF0F2438` |
| `caminoNavigationYellow` | `0xFFFFD740` | `0xFFF5C75A` |

`lib/ui/app_theme.dart`

| Constant | Old | New |
|---|---|---|
| `caminoSurface` | `0xFF132B45` | `0xFF16304A` |
| `caminoSurfaceHigh` | `0xFF1B3857` | `0xFF1E3B58` |
| `caminoSurfaceBorder` | `0xFF284D73` | `0xFF2E4F72` |
| `caminoAmberSubtle` | `0xFFF9E8C7` | `0xFFF6E3BC` |

## 2. ColorScheme values in `buildCaminoTheme()`

| Field | Old | New |
|---|---|---|
| `onPrimary` | `0xFF1B1800` | `0xFF231A00` |
| `primaryContainer` | `0xFF4A3700` | `0xFF4A3A12` |
| `secondary` | `0xFF64B5F6` | `0xFF7DB8E8` |
| `onSurface` | `0xFFF1F5F9` | `0xFFF2F5F9` |
| `onSurfaceVariant` | `0xFFCBD5E1` | `0xFFBFCCDB` |
| `outline` | `0xFF8CA8C4` | `0xFF8FA9C4` |
| `error` | `0xFFFFB4AB` | `0xFFF4A59A` |

Also update the matching `onPrimary` / foreground colour in `filledButtonTheme` (`0xFF1B1800` -> `0xFF231A00`).

Leave `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainerHighest`, `secondaryContainer`, `onSecondary`, `outlineVariant` and the error container colours unless they look wrong next to the new surfaces.

## 3. Use the theme instead of hard-coded slate text colours

In `buildCaminoTheme()`, the text theme uses literal colours (`0xFFF8FAFC`, `0xFFF1F5F9`, `0xFFE2E8F0`, `0xFFCBD5E1`) and the button/input themes use `0xFFE2E8F0`, `0xFFCBD5E1` and `0xFF8CA8C4`. Replace them with `colorScheme.onSurface`, `colorScheme.onSurfaceVariant` and `colorScheme.outline` so the new values apply everywhere.

## 4. Semantic colours

`lib/ui/camino_colors.dart` already exists (a `ThemeExtension`) but is not wired in. Do this:

1. Update `CaminoColors.dark` to:
   - `gpsGood`: `0xFF7EDDA9`
   - `gpsStale`: `0xFFF0A35A`
   - `routeLine`: `0xFF1F5FAE`
   - `routeCasing`: `0xFFFFFFFF`
   - `nextWaypoint`: `0xFFF5C75A`
   - `offRoute`: `0xFFF4A59A`
2. Register it: `extensions: const [CaminoColors.dark]` on the `ThemeData` returned by `buildCaminoTheme()`.
3. Replace hard-coded colours with `CaminoColors.of(context)`:
   - `map_screen.dart`: route line `0xFF1456A0` -> `routeLine`; `borderColor: Colors.white` -> `routeCasing`; next-waypoint label `0xFFFFD54F` -> `nextWaypoint`; off-route warning styling -> `offRoute`.
   - `today_progress.dart`: GPS icon `Colors.greenAccent` -> `gpsGood`, `Colors.amber` -> `gpsStale`.
   - Any other GPS-status colour (check `position_controls.dart`, `compass_layer.dart`, `navigation_summary.dart`).
4. Find the rest with: `grep -rnE "Colors\.|Color\(0x" lib/ui` and convert anything that is a brand or status colour. Leave map-tile background colours (e.g. `0xFFE6EBDF`) and white/black used on top of map imagery as they are.

## 5. Constraints and checks

- Do not change `surfaceContainer*` roles used by existing widgets other than the values listed above.
- Contrast was checked for these pairs: text on background 14.4, text on card 12.3, muted on card 8.3, muted on raised surface 7.1, gold on background 8.1, gold on card 6.9, `0xFF231A00` on gold 8.8, route line on map tile 5.2. Do not pick lighter greys or darker golds that would reduce these.
- The `Fiesta` and `Inter` font setup is unchanged.
- Run `dart format`, `flutter analyze` and `flutter test`. Fix any test that asserts an old colour value; do not delete tests.
- Do not touch unrelated files. Report the files changed and the new version and build number.
