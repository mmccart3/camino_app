# Map: cafes, bars and shops only appear when zoomed right in

Read `AGENTS.md` first. This is one completed app update: bump the patch
version and build number once in `pubspec.yaml` and report the result. Change
only what is listed here.

Problem: on the map, places such as the cafe at A Serra do not appear until the
user has zoomed in a long way.

Diagnosis (checked against the bundled data, not guessed):

- `assets/offline_maps/style.json` already shows POI icons from zoom 12 and
  labels from zoom 13, so the style is not the limit.
- The vector tiles are. In `stages1_34_valcarlos_complete.mbtiles` (max zoom 14)
  the tile around A Serra (42.77099, -7.46704) has 1 POI at zoom 12, 1 at zoom
  13 and 29 at zoom 14, and the only cafe is in the zoom 14 tile. The map opens
  at zoom 13 (`map_screen.dart`, `initialZoom: 13`), so a walker sees no cafes
  until they zoom in past that.
- The app's own database already has the answer: `locations.hasBarCafe`,
  `hasPharmacy` and `hasGroceryStore` (A Serra has `hasBarCafe = 1`, source
  OSM node 792227043). The map screen does not draw them; the icons appear only
  in lists (`screens.dart`, `ahead_screen.dart`).

Required:

1. Draw facility badges on the map location markers from the database flags:
   a small cafe icon when `hasBarCafe == true`, a pharmacy icon when
   `hasPharmacy == true`, a shop icon when `hasGroceryStore == true`. Reuse the
   icons already used in `location_facilities.dart`. Show them from zoom 11 and
   up, independent of the tile data. Keep the marker tap targets at 48 dp and
   avoid clutter: at most three small badges per marker, and hide the labels
   below zoom 12.
2. Add a "Show" filter on the map (cafes, pharmacies, shops, all off by
   default is fine, remembered between visits) that highlights only locations
   with that facility.
3. Optional second step, only if time allows: extract the cafe, bar, pharmacy
   and supermarket POIs from the zoom 14 tiles of the bundled mbtiles into a
   small asset (JSON or a database table) and draw them as markers from zoom 12,
   so unlisted cafes between villages also show up earlier. Do not rebuild or
   replace the mbtiles file.
4. Add a widget test that a location with `hasBarCafe` shows the cafe badge at
   zoom 12 with tiles turned off.

## Checks

`dart format .`, `flutter analyze` and `flutter test` must all pass. Fix tests
that assert changed markers or layout; do not delete or skip any. Check on a
device or emulator: open the Stage 1 to 34 map at the default zoom and confirm
badges appear on villages that have a cafe, pharmacy or shop, at a readable size
and without covering the route line. Report files changed and the new version
and build number.
