# Replace the map POI icon sheet with the new original icons

Read `AGENTS.md` first. This is one completed app update: bump the patch
version and build number once in `pubspec.yaml` and report the result. If the
map facility badges brief (`docs/map_facility_zoom_brief.md`) is done in the same
pass, bump once for both.

## Why

- The current sheet (`assets/offline_maps/poi_icons*.png`) has no known author
  or source, and the licence file is only the generic Creative Commons text. It
  cannot be credited properly, so it should not ship.
- Several icons were identical (bar and pub; supermarket, convenience and
  greengrocer; doctors, clinic and hospital) and all were one navy colour.

## What is ready

New original icons are already in `assets/offline_maps/poi_icons_new/`:
`poi_icons.png/.json` (1x), `poi_icons@2x.png/.json`, optional `@3x`, the 16 SVG
sources in `svg/`, and `ICON_LICENSE.txt`. A preview is in
`docs/poi_icons_preview.png`. They use the same 16 names, the same order, and
the same size (32 dp, 64 px at 2x) as the old sheet, so this is a drop-in swap.

Colours by need (white glyph on each): eat and drink amber `#A85A00`, shops
purple `#7A4FA3`, pharmacy green `#1E8A47`, doctors, clinic and hospital red
`#C62F2F`, water blue `#1F5FAE`, toilets and ATM slate `#4A5B70`.

## Steps

1. Copy `poi_icons.png`, `poi_icons.json`, `poi_icons@2x.png` and
   `poi_icons@2x.json` from `assets/offline_maps/poi_icons_new/` over the files of
   the same name in `assets/offline_maps/`. Do not change `style.json`
   (`"sprite": "asset://assets/offline_maps/poi_icons"`, `icon-size: 1` stay as
   they are). Do not add the `@3x` files to `pubspec.yaml` unless the map
   package is confirmed to load them.
2. Replace the contents of `assets/offline_maps/poi_icons_license.txt` with the
   contents of `poi_icons_new/ICON_LICENSE.txt` (keep the file name, because
   `pubspec.yaml` lists it).
3. Delete the `poi_icons_new/` folder only if you want to avoid duplicates; keep
   `svg/` somewhere (for example `assets_src/poi_icons/`, not listed in
   `pubspec.yaml`) so the icons can be edited later.
4. Check `lib/ui/` for any other place that shows these sprite icons or a legend
   for them, and update it if it exists.
5. Credits: make sure the app's About or credits text says "Map data
   (c) OpenStreetMap contributors" and "OpenMapTiles". The icons need no credit.
   Remove any text that credits the old icon set, if there is any.

## Checks

`dart format .`, `flutter analyze` and `flutter test` must pass. Fix tests that
reference the old sprite; do not delete or skip any. Check on a device: at zoom
14 and above, cafes, bars, pharmacies, shops and water points show the new
coloured icons, readable at 32 dp, and no icon is cut off at the tile edge.
Report files changed and the new version and build number.
