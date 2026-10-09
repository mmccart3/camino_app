# Phone compass (0.2.85+90)

Stage Route and guidance and Navigate here offline now show a yellow direction arrow at the current/last requested GPS position. The arrow shows where the top of the screen points, including while stationary. The badge gives a magnetic heading even before requesting a GPS position. Updating the compass does not refresh a manually requested GPS fix.

Hold the phone approximately flat. Long-press the badge for calibration guidance. An unavailable or unreliable sensor keeps the ordinary position marker; no direction is invented. Windows has no compass integration. The arrow represents magnetic north, so it is approximate relative to the map's geographic north. It does not indicate the direction to a waypoint or provide turn instructions.

The native camino/compass event channel uses Android rotation-vector sensors (geomagnetic rotation vector fallback) and iOS Core Location heading only. It requests no additional GPS session or background permission. Dart cancels subscriptions when the route is offstage, the application is hidden, or the map is disposed; native code also stops on backgrounding. Heading smoothing crosses 0/360 by the shortest angle, readings expire after 15 seconds, and map rotation is applied once by the marker layer.

Device checks: request position on Android/iPhone, rotate while stationary, verify N/E/S/W with the phone compass, rotate the map, try portrait/landscape, cover with another screen and lock/unlock, and verify low-accuracy behaviour away from magnetic objects. iOS compilation requires a Mac. Existing off-route alerts are independent.

Validation: Dart formatting and analysis completed without issues. Direct Kotlin compilation against the installed Android/Flutter APIs and the circular-heading checks passed. Flutter widget tests are present in test/compass_test.dart but could not run because the Windows objective_c native-asset hook compiler crashed before the tests started. Native iOS compilation and physical-sensor testing remain outstanding.

Version 0.2.87: maps start north-up. Tap Compass up to rotate the map smoothly with the phone heading; tap North up to reset. Dragging, zooming or rotating manually pauses automatic rotation; Resume compass restores it. Centre and zoom are retained. Unreliable readings pause rotation until reliable readings return. Sensors and rotation stop while the map is hidden.
