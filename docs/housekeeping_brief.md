# Housekeeping: line endings, unused files, stray files

Read `AGENTS.md` first. No app behaviour and no bundled asset changes in this
task, so it is not an app update: do not bump the version unless `AGENTS.md`
says housekeeping must also be bumped. Do not run `git commit`, `git add
--renormalize`, `git rm` or any other git command that changes the index or
history; leave the working tree changes for the owner to review and commit.
Never delete anything without first copying it somewhere outside the repo, as
described below.

## 1. Line endings

The working tree is CRLF and the index is LF, so plain `git diff` shows whole
files as changed and hides the real edits.

- Add `.gitattributes` at the repo root:

  ```
  * text=auto eol=lf
  *.sqlite binary
  *.mbtiles binary
  *.png binary
  *.jpg binary
  *.jpeg binary
  *.ttf binary
  *.pdf binary
  *.ico binary
  ```

  (`*.bat`, `*.cmd` and `*.ps1` may stay CRLF: add `*.bat text eol=crlf` and the
  same for `.cmd` and `.ps1` only if such files exist.)
- Add `.editorconfig` with `root = true`, `[*]`, `charset = utf-8`,
  `end_of_line = lf`, `insert_final_newline = true`, `indent_style = space`,
  `indent_size = 2`.
- Do NOT renormalise or convert files yourself. Tell the owner to run
  `git add --renormalize .` and review the result when they commit.
- Report the output of `git diff --stat` before and after, to show the noise is
  gone for the files that were only line-ending changes.

## 2. Unused map files (565 MB in `assets/offline_maps`)

Facts checked in the repo:

- `pubspec.yaml` bundles only `assets/offline_maps/stages1_34_valcarlos_complete.mbtiles`
  (24 MB), plus `style.json` and the `poi_icons*` files.
- `lib/services/offline_map.dart` and two tests refer only to that file.
- 36 other `stages1_*.mbtiles` files (about 540 MB) are tracked in git but are
  neither bundled nor referenced by `lib`, `test` or `tool`.

Do this:

1. Check that nothing in `tool/`, `scripts/` or the docs rebuilds the combined
   file from the per-stage files. If something does, list it in the report and
   stop this step.
2. Otherwise move the 36 unused `.mbtiles` files to a folder outside the repo
   (for example `..\camino_app_archive\offline_maps\`), verify the copy by file
   size, then remove them from `assets/offline_maps/`. Do not touch
   `stages1_34_valcarlos_complete.mbtiles`, `style.json` or any `poi_icons*` file.
3. Run `flutter test` and a release build size check (`flutter build apk
   --analyze-size` or compare the APK size before and after). The shipped app must
   be unchanged; only the repo and working tree get smaller.
4. Report the size of `assets/offline_maps` before and after.

## 3. Old elevation chart images

`assets/elevation_charts/` (36 files, 3.2 MB) is not listed in `pubspec.yaml`, and
`test/published_image_test.dart` asserts that no `elevation_charts/` key is in
`StageImageAssets`. The app draws generated charts instead.

- Search `lib`, `test`, `tool` and `docs` for any use. `tool/bundle_stage_images.py`
  mentions elevation charts: read it, and report whether it is still needed.
- If nothing needs the PNGs, move the folder outside the repo with the map files
  and keep the test guard as it is. If something does, leave the folder and say what.

## 4. New POI icon folder

If `assets/offline_maps/poi_icons_new/` still exists after the sprite swap:

- Move its `svg/` folder to `assets_src/poi_icons/` (not listed in `pubspec.yaml`).
- Delete the duplicate PNG and JSON files in `poi_icons_new/` once the copies in
  `assets/offline_maps/` match them byte for byte.
- Keep `ICON_LICENSE.txt` content only as `assets/offline_maps/poi_icons_license.txt`.
- Leave `docs/poi_icons_preview.png`.

## 5. Stray files in the repo root

These are not tracked but clutter the project folder: `test-results.txt`,
`stage15_map_analysis.log`, `test_stage15_run.log`. Move them to the archive
folder outside the repo, and add `test-results.txt` to `.gitignore` (`*.log` is
already ignored).

## 6. Dependency report (report only)

Run `flutter pub outdated` and paste the summary: which direct dependencies have
newer versions, and which are held back by constraints. Do not change any
version in `pubspec.yaml` in this task.

## 7. Docs

Move the briefs in `docs/` that are finished (palette, UI polish, consistency,
map zoom, Today card, icons swap) into `docs/briefs/` without editing them. Keep
`docs/poi_icons_preview.png` where it is.

## Checks

`dart format .`, `flutter analyze` and `flutter test` must pass. Confirm the
bundled map file, `style.json` and `poi_icons*` files are unchanged. Report every
file added, moved or removed, and every folder you moved outside the repo.
