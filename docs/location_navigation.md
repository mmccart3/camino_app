# Offline navigation to a location

Version 0.2.3 adds **Navigate here offline** on each location page. Tap it to check the installed map and request a foreground GPS fix. If the destination or any part of the journey lacks detailed offline tiles, an explanation and **Navigate with Google Maps** appear. GPS failures and missing track connections also offer that fallback. Google Maps is opened only when selected and may need internet access.

The planner uses the existing `paths` location relationships and ordered `track_points` predecessor chains. It can traverse connected paths across stages in either direction. It does not calculate street routes. Starts must be within 150 m of a stored track point and destinations within 150 m of their associated path endpoint. Gaps over 250 m within a path or incompatible predecessor links between paths are not routed across. Path joins must share a declared location and lie within 150 m. It can use valid portions of stages whose full-stage endpoint validation fails; it does not change the existing full-stage validation.

The displayed polyline ends at the destination's associated track endpoint. A separate flag shows the actual location. Final approach distance and the walk onto the track are explicitly excluded from estimates; no invented street route is drawn. Follow local signs for the final approach.

Distance sums incoming `distance_3d_meters`. ETA sums `weighted_distance / saved paceKmh` in seconds and displays minutes. Incoming metrics are reassigned to their corresponding edges when reversing travel. Reverse estimates retain the database weights, so uphill/downhill effects may differ. Missing metrics remain unavailable; unmeasured joins are not silently given a zero distance or time.

Coverage checks look for actual nonempty tiles at the MBTiles archive's highest native zoom, sampling route segments every 25 m, including the current position and final location. This detects gaps that the archive's bounding box would miss. Tile presence cannot guarantee every feature inside a partially clipped edge tile exists. No online tiles are fetched by this screen.

GPS updates run while the destination screen is visible, pause when the app is hidden or locked, and stop on leaving the screen. Arrival means a fresh fix with accuracy within 50 m places the user within 30 m of the location pin. This destination feature does not start or replace the separate opt-in screen-locked stage alert session.

To install the feature on Android, build and install a new APK from this source. Replacing only the SQLite file cannot add the new button.
