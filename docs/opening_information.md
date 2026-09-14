# Albergue opening information

The displayed columns are `openingPeriod` (season) and `checkInTimes` (arrival hours). Existing `check_in_opens` and `check_in_closes` are retained unchanged for provenance and compatibility. The row-level audit preserves every original opening field.

Missing seasonal information uses "Easter week till mid October (assumed; confirm with accommodation)". Missing or malformed check-in endpoints use 14:00 for the start and 20:00 for the end, labelled individually as assumed. Usable recorded endpoints are retained. Time-only notes with uncertain meaning are shown as original notes for confirmation; they are not treated as seasonal dates. Source comments and seasonal exceptions are preserved. These assumptions are not verified accommodation policies.

The database asset is copied to a new content-addressed device file after rebuilding/reinstalling. Preferences are unaffected.
