# Offline elevation profiles

## Using the app

Open **Trail elevation** from Home for an overview of every stage. Stages with samples have charts; unsupplied stages are explicitly unavailable. Alternative stages stay separate and are never concatenated into the primary route. Open **Explore this profile**, or **Explore elevation profile** on a stage page, for tap inspection, a sample slider and pinch zoom.

**Update my route elevation** obtains one foreground GPS fix and shows the nearest dataset sample within 35 m as an orange marker. The fix must be no older than two minutes and its reported horizontal accuracy must be at most 50 m. It reports route elevation from the CSV, not GPS altitude. Tap again to refresh as you walk. GPS permission denial, poor accuracy and absent nearby samples produce an unavailable message, never a guessed elevation. White marks the manually selected sample. The chart and sample queries work offline; no online elevation API or background GPS is added.

## Current coverage and limitations

The supplied `track_points_10m.csv` has 12,520 samples across paths 1–42: stage 1 through stage 5, plus part of stage 6. Path 43 and subsequent paths have no samples yet. Existing track_points and published charts are preserved.

The source distance column is `distanceAlongPathMetre` and contains 10 on every row. The owner confirmed this is the sampling interval, with the first sample at local distance zero. Source sequence runs globally from 0 to 12,519. The importer preserves it in `sourceSequence`, resets `sequence` per path, and calculates `distanceAlongPathMetres = local sequence * 10` in explicit interval mode. Elevations and coordinates are retained as supplied. No synthetic samples or endpoint elevations are added.

Path boundaries are not necessarily coincident: paths 35–36 have about 1,766 m between supplied coordinates, and paths 36–37 about 1,630 m. Several other joins are tens of metres apart, including about 123 m between paths 5–6. Location pins also differ from some sample endpoints. These are recorded for review, not automatically corrected. See `elevation_import.json` for sample counts, endpoint offsets and internal gap diagnostics.

Each path is drawn independently. No elevation line bridges different paths, and unusually large internal coordinate gaps are also left unconnected. The horizontal axis concatenates sampled lengths only and is labelled **Sampled distance (km)**. Missing joins, exact path endpoints and missing paths are not included in that distance. It must not be used as full route mileage or for navigation timing. Point inspection states distance from the first sample in its path. More accurate cumulative distances and exact endpoints can replace this initial interval-based dataset later.

## Schema

`elevation_points` uses `(pathID, sequence)` as its primary key. Columns are `distanceAlongPathMetres`, `elevationMetres`, `latitude`, `longitude`, `sourceSequence`, `distanceBasis` and `sourceSHA256`. Paths link to the existing `paths` table. No changes are made to track_points, weighted walking times, guide content or existing URLs. Older app databases without this optional table show an unavailable profile.

## Importing future CSVs

Run from the Flutter source folder with Python 3 (standard library only):

```powershell
python tool/import_elevation.py assets/database/camino.sqlite docs/track_points_10m.csv camino_with_elevation.sqlite --interval
```

Interval mode requires a positive constant interval and contiguous source sequences within each path. The first sample is treated as zero. For exact cumulative distances (0, 10, 20, ..., exact endpoint), omit `--interval` and use `distanceAlongPathMetres`. Both spellings of the distance header are accepted. All other columns match the supplied CSV.

The importer validates numeric values, coordinates, path IDs, duplicate sequences and increasing distances before writing. It creates a **new database**, refuses to overwrite an existing file, and writes a neighbouring `.elevation.json` audit. Imported paths replace only their own elevation samples; other paths and tables remain untouched. Keep a backup, review the audit, then replace the bundled SQLite asset and rebuild/install. The existing fingerprint-based first-launch copy picks up the new asset while preserving separate user settings.

Validation: `python tool/test_import_elevation.py`, `flutter test test/elevation_test.dart`, and `flutter analyze`.
