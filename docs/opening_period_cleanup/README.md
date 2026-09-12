# Albergue opening period cleanup

Updated 569 of 775 albergue rows. Spanish wording was translated and date ranges standardised. Dates, seasonal qualifications, advance notice, group-only access, weekly closures and historical dates were retained. This is an editorial cleanup, not a fresh verification of current opening dates or prices.

Only `albergues.openingPeriod` was changed. All other data and the schema were compared with the backup and are identical. SQLite integrity and foreign-key checks passed.

`changes.csv` contains every before/after value. `needs_review.csv` lists 327 rows with empty periods, time-only descriptions, misplaced information, historical notes or invalid dates. Times have not been assumed to be check-in times or curfews. Invalid 31 November dates are explicitly flagged rather than silently corrected. Facility and pricing notes in this field were translated and marked as not recording an opening period.

`camino_before_opening_period_cleanup.sqlite` is the complete original backup. `camino.sqlite` is the cleaned database.
