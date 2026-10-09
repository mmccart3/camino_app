# My walking day

Open **My walking day** from Home. Choose starting and finishing places, then select a route if alternatives are offered. Set the true flat-ground pace (1.0–8.5 km/h), optionally add a date, and save the day. Tap a saved day to reopen or update it. Each plan and all plans can be deleted with confirmation.

The planner works offline, across published stage boundaries, using existing paths and verified track chains. Places without complete forward track coverage cannot yet be planned. Route options with disconnected geometry are excluded. Estimates sum corrected stored 3D distances and slope weights; walking time uses the existing true-flat-speed normalization. Walking estimates exclude breaks and accommodation detours; itinerary times include explicitly planned breaks. Ascent/descent and the combined zoomable elevation chart use recorded navigation-track elevations. The separate 10-metre elevation dataset and guide database are not modified.

A plan begins and ends at the recorded route near the selected places. Small gaps between separate stage recordings (up to 150 m) are explicitly excluded from estimates and disclosed on screen. No invented track segments or slope estimates bridge these joins. Path IDs are saved, rather than stale totals; opening a plan recalculates it against the installed guide. Invalidated routes are reported instead of silently substituted.

## Privacy and storage

Plans contain selected path IDs, walking pace, an optional date and a local identifier. They are stored under `walking_days_v1` in app preferences, separately from the replaceable bundled database. The planner performs no network requests, analytics or account synchronisation. Guide database updates do not delete saved plans.

The optional **Find a nearby starting place** button uses the existing foreground location service for one fix. The user confirms the suggested place. It does not save raw coordinates or start background tracking, and the plan begins at the selected place rather than at the GPS fix. Manual planning needs no location permission.

The phone's operating-system backup/device-transfer settings may include app preferences. The feature's privacy explanation discloses this; do not market it as excluding all operating-system cloud backups. No app-managed cloud synchronisation is provided. The released app's overall privacy notice should include this feature description alongside its existing location and external-link disclosures.

## Validation

`test/walking_day_test.dart` covers combined-stage totals, pace scaling, explicit alternatives, missing data, persistence, deletion, corrupted saved data, opening a plan on a narrow phone, and the privacy dialog.

## Starting and arrival times

Choose a starting time (default 08:00) in local Camino time. Each listed place shows its approximate arrival time from cumulative slope-weighted walking time at the chosen pace. Estimates round cumulative time up to the next minute and include planned breaks and exclude unplanned stops and the previously disclosed recording gaps. Times after midnight include a day offset. The optional date remains the walking-day date; itinerary clock calculations do not use the device timezone or apply daylight-saving transitions.

Departure time is saved as minutes after midnight. Existing saved plans without this field default to 08:00. Route, pace or starting-time changes update the displayed itinerary; use Update saved walking day to retain edits.

## Planned breaks (0.2.76+81)

At intermediate locations choose Add break: 15, 30 or 60 minutes, or a custom whole-minute duration from 0 to 1440. No break removes the stop duration. The start time means departure, and the day ends on arrival at the destination, so breaks are offered only between those endpoints.

A break changes departure from that location and all subsequent arrivals, but not arrival at the break location or the walking estimate. The summary separates walking time, planned breaks and overall duration. Breaks are keyed by location ID, retained when pace changes, and only counted for intermediate locations on the selected route. Saving writes only applicable breaks. Older saved days default to no breaks. No extra data leaves the device.
