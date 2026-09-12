# Camino: offline Flutter MVP using the real database

The app uses the populated `assets/database/camino.sqlite` in this project. It does not create a new schema or replace your data with a sample. The SQLite file and its URLs were left unchanged. The old fictional fixture generator has been removed.

## Run and validate

From `C:\Users\markj\src\camino_app_parts\camino_app`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d windows
```

Flutter with Dart 3.10+ is required. Android and iOS runner projects are included. iOS packaging requires macOS and Xcode. The MVP supports Android/iOS and Windows. Windows uses SQLite FFI and stores installed copies in the per-user application-support directory; Android/iOS use sqflite. Web is not supported. Dependencies are pinned by `pubspec.lock`.

## Existing schema mapping

Dart classes map directly to your existing columns; each model also retains an immutable `source` row containing fields the MVP does not yet display. No tables, columns, views or migration DDL are added.

| Dart model | Existing table | Relationships and ordering |
| --- | --- | --- |
| Stage | stages | ID, stageStartLocationID, stageFinishLocationID; priorStage/nextStage and alternative links retained |
| Location | locations | ID; stage membership comes from paths and declared stage endpoints, not a fabricated stage_id |
| Paragraph | paragraphs | locationID; paragraphType and paragraphText; ID display order because no sequence column exists |
| Albergue | albergues | ID, locationID; original rates, address, photos, opening times and booking fields |
| PrivateAccommodation | privateAccommDetail | ID, locationID; original privateAccomm fields; no photo columns exist in this table |
| Path | paths | pathID, stageID, originLoc, destinationLoc; one location-to-location segment |
| TrackPoint | track_points | track_point_id, pathID, previous_track_point_id, waypoint, elevation and distance metrics |

Original spellings such as `onedPersonRateMin`, `twodPersonRateMax` and `StreetAdress` are intentional in the mappings. `mapLocationCoords` is preserved but not queried: its pixel coordinates belong to the published raster maps, not geographic route geometry.

Stage list badges are database IDs, not consecutive walking-day numbers. Stages follow the stored nextStage links, with altNextStage immediately after the corresponding primary next stage. Parallel branches are traversed together and shared destinations appear once. Starting stages (including Valcarlos) appear first; IDs only break ties between starts or disconnected records. Missing links and cycles cannot hide stages or cause an infinite loop. Detail buttons follow the same stored links. Paragraphs appear on their owning location detail, not as invented stage paragraphs. Nulls remain null in the models.

## Asset import and first launch

Existing MySQL database → converted SQLite database → Flutter asset → device database storage → local read-only queries.

The supplied database is already SQLite. For future MySQL exports, perform schema-aware conversion outside Flutter: translate MySQL-specific syntax/types while preserving tables, IDs, relationships, text and URL strings. Do not import a MySQL dump directly as SQLite SQL.

1. Edit/convert a working copy with a SQLite editor, keeping the existing schema.
2. Run `python tool/audit_database.py path/to/camino.sqlite`. It only reads the database and prints JSON with DDL, row counts, route coverage, graph issues, orphan counts and encoding observations.
3. Verify source/export row counts, coordinates, links and text. The current database has no declared foreign keys or primary-key constraints; a clean SQLite foreign_key_check alone therefore does not prove relationship correctness. The audit includes explicit joins.
4. Preserve Cloudinary URLs and Booking.com strings exactly, including `aid=1627093`, percent encoding, parameter order and any other affiliate parameters. Do not rebuild URLs.
5. Checkpoint any WAL and close the editor so the database is a complete standalone file, then replace `assets/database/camino.sqlite`.
6. Run Flutter validation and rebuild the app.

`LocalDatabase` reads the asset bytes, writes a temporary file, validates SQLite integrity, required columns and unique/non-null IDs, closes the temporary database, then renames it into the device database directory. It opens the installed database read-only. Concurrent calls on the shared app instance reuse one opening future. Failed asset copies can be retried and are not promoted; existing installed data is never overwritten automatically.

The installed filename is **camino-<SHA-256 of bundled bytes>.sqlite**. On each full startup the app reads and fingerprints the asset. An unchanged asset reuses its existing installed copy. A changed asset is validated and copied under a new filename, leaving prior copies and walking pace untouched. Older fixed filenames (camino-v1.sqlite and camino-schema-v2.sqlite) are no longer selected.

After editing the bundled asset, stop the running app and run Flutter again from this project folder to rebuild the asset bundle. Hot reload does not rerun database initialization. No clearing app data or uninstalling is required. This selects the database packaged with the current app build; there is no network sync or MySQL connection. Old copies are retained for now; pruning and user-editable database migration are outside this MVP.

## Route assembly and guidance

`RouteAssembler` follows paths from the stage's declared start location to its finish. It rejects ambiguous branches, cycles, missing continuations and unused paths instead of guessing. Locations remain browsable when their route order is invalid.

For each path, track points are ordered by `previous_track_point_id`, not numeric ID or insertion order. A path's first predecessor may reference the previous path's final point, as your dataset does. Duplicate IDs, forks, cycles and disconnected chains are rejected. Across paths, predecessor links and spatial continuity are checked. Conservative geometry checks flag gaps over 150 m between paths, 250 m within a path, or endpoints more than 150 m from their declared locations; these thresholds can be reviewed for future datasets.

A fully validated stage renders one polyline and enables guidance. Incomplete stages render only actual available segments and location markers; the app never creates straight-line trails between locations with missing track points. Full-stage guidance is disabled for incomplete/invalid geometry.

Waypoint flags come from the database. Flagged segment endpoints use the corresponding location name; other flagged points have an ID-based label. The stage finish is the final fallback waypoint.

Guidance finds the nearest stored track point by GPS distance, then selects the next flagged/named waypoint ahead in route order (or the stage endpoint). Each row's `distance_3d_meters` and `weighted_distance` describe the incoming segment from `previous_track_point_id`. Sums therefore start at the row AFTER the nearest point and include the destination waypoint. The nearest point's incoming segment is already behind the user and is excluded.

Remaining distance is `SUM(distance_3d_meters)`. The database owner's confirmed time convention is `SUM(weighted_distance) / paceKmh` in seconds; divide by 60 for minutes. No additional factor of 1000 or 3.6 applies to weighted values. Times are summed before rounding and displayed rounded up to whole minutes. The same calculations extend to the stage end. Missing, negative or non-finite metrics produce an unavailable estimate rather than a guessed horizontal-distance substitute.

Average walking pace is saved locally, defaults to 4.6 km/h, and is adjustable from 1.0 to 8.5 km/h in 0.1 increments. Existing valid saved preferences are retained. This is the user's chosen average, not an automatically learned speed. Change it in Settings and save it.

Equal nearest-point distances choose the earliest point in route order; there is no heading/history map matching at crossings. A waypoint at the nearest point is treated as reached. Estimates exclude breaks and travel back to the selected track point. The UI shows that point's ID, GPS accuracy, timestamp and distance from it. Position updates remain explicit button presses, not continuous navigation.

## Offline and external content

All guide records, available route geometry and walking pace work offline. flutter_map online tiles load by default when a map screen opens. The Online basemap switch can disable them for that screen. OpenStreetMap attribution is displayed directly on the map while tiles are enabled. Before release set your real application identifier and review your tile provider's usage policy. There is no bulk tile downloading.

Photos and published stage maps/elevation charts load from their stored Cloudinary HTTPS URLs, with an unavailable-image fallback. There is no durable offline photo cache. Private accommodation currently has no image URL columns, so no images are invented.

The website and booking URL launcher accepts only valid HTTPS links with no embedded credentials or control/space characters. It passes the original database string to url_launcher's string API, without reconstructing query parameters. Stored sentinels such as “not on Booking” and “no website available” are retained in models but do not produce clickable buttons. Legitimate non-HTTPS URLs are also not launched by this policy.

Location uses geolocator for one user-triggered foreground fix with permission handling and a timeout. Android has fine/coarse location and internet permissions; iOS has a when-in-use usage description and the CocoaPods always-permission bypass flag. No background GPS, GPS foreground service, authentication, payments, backend sync or voice guidance is implemented.

## Dataset observations

The inspected asset contains 41 stages, 253 locations, 387 paragraphs, 460 albergues, 670 private accommodation records, 286 paths, 2048 track points and 318 mapLocationCoords rows.

- Track geometry covers stage 1 (paths 1–8, 778 points) and stage 2 Roncesvalles to Zubiri (paths 9–14, 1270 points, added 11 September 2026). Other stages remain available as guide content and map markers.
- Stage 24 has two outgoing paths from location 124: path 124 to location 130 and path 125 to location 132. The app flags this ambiguity.
- Stage 25 has path 130 from location 133 back to 133; its declared finish is location 134. The app flags the cycle. No data corrections were made.
- The read-only audit found no orphaned paths, track points, accommodation records or paragraphs in the checked relationships, and no stored Unicode replacement characters. Text is passed through unchanged.

These observations are about the supplied snapshot, not hard-coded app limitations. Adding complete valid track data enables guidance for additional stages.

## Code and verification

`lib/data`: existing-schema models, schema validation, local asset copy, repositories and route assembly.
`lib/services`: geometry/ETA, pace preferences, foreground location and safe URLs.
`lib/ui`: Home, stage list/detail, location detail, albergue detail, private accommodation detail, map/navigation and settings.
`test`: real SQLite integration, graph/geometry edge cases, offline UI and preferences.
`tool/audit_database.py`: reusable read-only audit.

Tests cover all seven table concepts, every stored booking URL, all-stage browsing, first-copy/reopen/read-only behavior, failed import retry, old-fixture coexistence, schema mismatch/duplicate IDs, full-stage route ordering, invalid routes, missing tracks, offline polyline rendering, screen navigation and pace persistence. Test mutations use temporary copies, never the source asset.

Native APK/IPA packaging and physical-device GPS/permission behavior require separate device validation. A Flutter asset-bundle build checks Dart compilation and asset inclusion but does not replace that testing.

## Validation results for this revision

Dart formatting completed; Flutter analysis reports no issues; all 32 tests passed, including automatic Windows SQLite selection. The native Windows release executable built successfully; its bundled database is byte-identical to the source and contains all 41 stages. UI launch on the user desktop has not been independently verified. Native APK/IPA packaging and device GPS were not tested.

The source SQLite SHA-256 before and after this work is `74f0d58ca43ee25e1cc9f0efed1983762bf8d1c7049d7979958777f9a049347b`.

## Windows executable

Close the old Camino window. Extract the complete camino_windows.zip archive and open Camino Windows/camino_app.exe. Keep its DLLs and data folder alongside it. From source, use flutter run -d windows in the project folder shown above. The previous build/windows/x64/runner/Debug output contained the demo asset; the new Release output contains the real database.

## Phone and WhatsApp links (0.1.1)

Both accommodation detail screens now show clickable primary and secondary telephone numbers from tel1CountryCode/tel1PhoneNumber and tel2CountryCode/tel2PhoneNumber. Country codes and numbers are combined into validated international tel: targets. Zero, missing and invalid numbers are hidden; identical primary/secondary numbers are shown once. Explicit + or 00 international numbers take precedence over the separate country-code field. No country code is guessed for a national number that lacks one, and source records remain unchanged.

Windows opens the configured calling application. If launching fails, the app displays an error and the number for manual dialing. No automatic calls are placed by the app. Telephone links have their own strict allowlist; booking and website links retain the HTTPS-only policy and unchanged query strings.

WhatsApp buttons use https://wa.me/<international digits> only when an explicit whatsAppNumber is present. They open a chat without composing or sending a message. A telephone number is never assumed to be on WhatsApp. Store full international WhatsApp numbers, including country code (for example 34600123456 or +34600123456); formatting spaces/hyphens are accepted. This is format validation, not verification that a number is registered with WhatsApp.

The updated database imported on 8 September 2026 contains 239 populated albergues.whatsAppNumber values; all pass the app's international-number format validation. The privateAccommDetail update imported on 9 September 2026 includes 226 populated WhatsApp numbers. Its removed secondary-phone columns are optional in the app. The updated table contains 670 records. Booking URLs are preserved as supplied, including URLs from which the affiliate query parameter has been removed.

After populating numbers, rebuild and fully restart the app; the asset fingerprint selects the updated dataset. Test contact details are synthetic and confined to tests; no real calls or messages were made during validation.

References: [url_launcher](https://pub.dev/packages/url_launcher), [WhatsApp click to chat](https://faq.whatsapp.com/5913398998672934).

## Default basemap and future offline packages (0.1.2)

Opening a map now loads OpenStreetMap tiles for the visible viewport by default. Normal tile requests use flutter_map 8.3.2 NetworkTileProvider and its built-in disk cache, which honors HTTP freshness headers. The app identifies itself as CaminoGuideOfflineMVP. Cache contents can be evicted and are not a guaranteed offline map. Route data remains in SQLite and is unaffected by the basemap switch or network availability. Tests use in-memory test tiles, not actual network downloads.

The public tile.openstreetmap.org service prohibits bulk downloading, prefetching and creation of tile archives for distribution. No pre-download service, hidden pan/zoom sweep or offline-download button has been added. See https://operations.osmfoundation.org/policies/tiles/.

Maps can be included in an app installation if their source explicitly permits offline redistribution. A future implementation can bundle a licensed raster tile archive (for example MBTiles) or a suitable vector map package with its required style, fonts and attribution. Copy/open the package locally and connect a local tile provider/renderer to flutter_map. This requires selecting coverage and zoom/detail levels and sourcing or generating a legally redistributable package; it has not been implemented in this revision. A corridor along the Camino would limit package size compared with entire countries. Such a package would be separate from camino.sqlite, retaining the existing guide-data schema.

## Google Maps walking link (0.1.3)

Every accommodation detail screen shows Walk here with Google Maps under Contact & directions when valid gps_lat/gps_lng coordinates are present. This does not depend on having a telephone or WhatsApp number. Missing, out-of-range, non-finite or (0,0) placeholder coordinates do not produce a link.

The app opens https://www.google.com/maps/dir/ with api=1, the encoded latitude/longitude destination, travelmode=walking and dir_action=navigate. No origin is sent: Google Maps handles the starting location, or asks the user to supply one. On Windows this opens in the browser; supported mobile devices can open the Maps app. Navigation versus route preview depends on the device and availability of the starting location. This link requires Google Maps connectivity and does not add background GPS or turn-by-turn navigation to Camino. Database coordinates and affiliate URLs remain unchanged.

Reference: https://developers.google.com/maps/documentation/urls/get-started#directions

## Apple Maps walking link

On iOS, both albergue and private accommodation details also show **Walk here with Apple Maps** under Contact & directions when valid GPS coordinates are available. Google Maps remains available alongside it. Windows and Android retain the Google Maps link only.

The HTTPS maps.apple.com link passes the stored coordinates as daddr and dirflg=w for walking. Omitting saddr lets Apple Maps resolve the starting point. It uses the existing safe external URL launcher. No database changes are needed.

Reference: https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html

Validated with automated URL and platform-specific widget tests. An iOS device build requires macOS and Xcode; native iOS launch behavior has not been tested on this Windows machine.

## Accommodation websites

Both accommodation detail screens show Visit accommodation website under Contact & directions for valid albergueWebsiteURL/privateAccommWebsiteURL values. HTTP and HTTPS websites open externally with the stored URL unchanged. Missing values and no website available placeholders are hidden. Booking affiliate links retain their existing HTTPS validation and exact stored URLs.

## Email and albergue facilities

Both accommodation types use the existing email column. Valid email addresses appear under Contact & directions and open the user's email composer; nothing is sent automatically. Surrounding whitespace is trimmed, NULL placeholders are hidden, and mail header injection is rejected. The current private accommodation email column contains only NULL placeholders, so those links will appear once real addresses are populated.

Albergues show numberOfDorms and labeled icons for washingMachineAvailable, dryingMachineAvailable, communalMealAvailable and kitchenFacilitiesAvailable. Stored 1 means Yes, 0 means No, and missing/unrecognized values mean Not recorded. The database is unchanged.

## OSM HTTP 403 / 429 handling

Native tile requests now explicitly identify the app as CaminoGuideOfflineMVP/0.1.3, retaining its existing product identity. The tile layer requests the visible viewport with panBuffer=0 and a native zoom ceiling of 19. flutter_map's built-in native disk cache remains enabled and honors expiry and conditional requests; no no-cache headers, scraping or bulk downloads are used.

HTTP 403 and 429 responses are treated as errors rather than rendered as tile images. The map removes the tile layer and disables further tile loading for the current app session, while route lines and markers remain available. Already in-flight requests may complete. This is not a guarantee of restored access: the previous library-formatted User-Agent already included the app name, and the actual server-side reason has not been established. Do not rotate identities, proxy requests or repeatedly restart to evade a block. If it persists, contact OSM operations or arrange a suitable licensed tile provider. No live requests to the blocked service were made during automated validation.

Policy: https://operations.osmfoundation.org/policies/tiles/

## Albergue affiliate removal (9 September 2026)

At the owner's request, removed the aid affiliate parameter from all 305 albergue Booking.com URLs that contained it. Accommodation page URLs remain usable. Private accommodation URLs were left unchanged in this update. Booking links without aid no longer display the affiliate label. This intentional database edit supersedes the original requirement to retain albergue affiliate ID 1627093.

## Published map and elevation images

Stage maps and elevation charts now retain their natural aspect ratio at the available width, without the fixed-height photo crop. Tap the image or Open full screen to zoom and pan; desktop users also have zoom-in, zoom-out and reset controls. Back returns to stage details. Accommodation photos retain their existing layout. Published maps and charts use bundled assets and work from first launch without internet. Cloudinary URLs are retained in the database as source references.

Published stage maps use the existing stages.stageMap1920URL field, including the full-screen viewer.

## Rebuilding the offline published-image bundle

Install Python 3 and Pillow (`python -m pip install Pillow`), then run `python tool/bundle_stage_images.py` from this folder. The script reads stages.stageMap1920URL and stages.stageElevationChartURL from the bundled SQLite database, downloads only these Cloudinary images with at most three concurrent requests, verifies their format, and keeps their original bytes. It never accesses OSM tiles or changes the database.

The script generates assets/stage_maps/, assets/elevation_charts/, assets/stage_images.json and lib/data/stage_image_assets.dart. Commit these files with the source. Unchanged URL/hash pairs reuse existing files; use --refresh to fetch again if an image changed at the same URL. The manifest records source URLs, SHA256 hashes, dimensions, byte counts and unavailable images. Review unavailable entries after each run before packaging. Then run dart format lib/data/stage_image_assets.dart, flutter test, and rebuild the application. New stages or changed URLs require regenerating the bundle and releasing the updated app.

The first bundle has 75 images (about 23.8 MiB). Stage 1's elevation-chart URL and stage 43's map URL return HTTP 404. Stages 15, 23, 25, 29 and 43 have no elevation-chart URL. These show Image unavailable in this app version; correct the database source URL and rerun the script to include them. No substitute image is invented.

Flutter reads these files directly from its asset bundle; there is no first-launch download or extra device-storage copy. Both inline and full-screen views use AssetImage and make no image network requests. The existing stage and accommodation database is unchanged. Accommodation photos and the interactive OSM basemap retain their separate network behavior; this feature does not create offline basemap tiles.

## Guide paragraphs populated from Word

The supplied Camino Frances AC.docx was imported into the existing paragraphs schema: 326 additional paragraphs, 387 total. Original rows and other tables are preserved. New rows use PLAIN, DIRECTIONS and HISTORY and existing location IDs. See docs/paragraph_import/IMPORT_REPORT.md and its CSV/JSON audit for classifications, source indices and detour mappings. Source prices and opening times are reproduced, not independently updated.

### Published map location links

Published stage maps load clickable rectangles from `mapLocationCoords`, filtered by `stageId` and joined to `locations.ID` through `locationId`. Coordinates come directly from `TLX1920`, `TLY1920`, `BRX1920`, and `BRY1920`, in original image pixels. Links open the existing location detail screen offline. Rectangles scale with the displayed image, account for full-screen letterboxing, and share the image zoom/pan transform. Hover shows the location name; links support keyboard activation. The full-screen button remains available separately.

Invalid/missing coordinates and missing locations do not create links. Partially out-of-bounds rectangles are clipped to the image. Current data issue: row 181, stage 30, location 163 has `BRY1920 = 0` below `TLY1920 = 204`; correct that row to activate its link. Row 48 on stage 7 extends to x=1915 while its bundled image is 1875 pixels wide, so its visible portion is clickable. No database coordinates were changed.

### Opening period wording cleanup

569 albergue opening-period descriptions were translated or standardised. Dates and qualifications were retained; uncertain source data is flagged rather than guessed. See `docs/opening_period_cleanup/README.md` and its before/after and review CSV files. All other database columns remain unchanged.
