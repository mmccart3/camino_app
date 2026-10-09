# Stage list

Stage cards retain repository nextStage/altNextStage ordering. Linked parallel route choices are identified by their shared predecessor. The last opened stage is highlighted and a Continue here button opens its detail screen.

Walking estimates sum incoming weights after the first route point and use WalkingTime with the saved true flat-ground pace. Incomplete guidance or missing weights do not produce a misleading estimate. Published distance stays sourced from the stage record.

Route and tile checks are lazy and cached for the lifetime of the list screen. Map availability checks the actual bundled detailed tiles along each segment and at recorded locations, without fetching online tiles. Map availability and guidance readiness are independent. Errors are displayed as unavailable checks rather than positive statuses.
