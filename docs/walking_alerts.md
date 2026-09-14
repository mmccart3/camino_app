# Walking alerts — setup and testing

## Using the feature

1. Rebuild/install the app from this source. Database-only updates do not add this feature.
2. Open a stage with a complete validated route (currently stages 1–3). Stage 4 retains its endpoint validation issue; alerts are disabled there until corrected.
3. Set and save an off-route distance on the map or Settings (default 50 m, range 20–500 m).
4. Start walking alerts and accept the heavy battery-use warning. Allow precise location and notifications. On iPhone, select Always under Settings > Camino > Location.
5. Lock the screen. Tracking continues as an explicitly started session. Android shows an ongoing GPS notification; iOS shows its background location indicator. Reopen Camino to stop using the global Stop walking alerts button.
6. Stopping cancels the location subscriptions. Closing the map alone does not stop the session. Force-closing, rebooting or an OS process termination ends tracking; the app never restarts it automatically.

Continuous high-accuracy GPS, an Android wake lock, and disabled automatic pausing on iOS can heavily drain the battery. Start charged, carry power if needed and stop promptly when finished. No battery-consumption measurement has been performed yet.

## Platform configuration

- Android: geolocator's foreground location service, FINE/COARSE_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, WAKE_LOCK and POST_NOTIFICATIONS. Start only while the app is visible. This does not require launching services from the background. No ACCESS_BACKGROUND_LOCATION or reboot receiver is added. The notification icon is retained for release resource shrinking. Java 17+ and core library desugaring are required; use Android Studio's bundled JDK.
- iOS: UIBackgroundModes/location, Always and WhenInUse purpose strings, visible background location indicator, fitness activity, automatic location pausing disabled. The former BYPASS_PERMISSION_LOCATION_ALWAYS CocoaPods flag is removed. Notification delegate is configured. Run Flutter pub get and pod install/build on a Mac, enable signing, and verify background location capability in Xcode. This repository's iOS build was not verified on this Windows host.
- Notifications: flutter_local_notifications 19.5.0, immediate local notifications only; no exact alarms, remote push or backend.
- Desktop: existing maps and manual location remain available; screen-locked alert sessions are mobile-only.

## Detection and privacy

Minimum distance to the line between track points (local metre projection for the short Camino segments), not nearest-point distance. No connections are invented between incomplete segments because alerts require a validated complete route. Three accurate chronological fixes over ten seconds must exceed the threshold even after subtracting GPS accuracy. Acceptable accuracy is at most half the threshold and no more than 50 m. Fixes older than 30 seconds, future-dated fixes and repeats do not build alert evidence. Long gaps reset the evidence. Return clearly within 70% of the threshold, accounting for accuracy, to rearm; a two-minute cooldown also applies.

The nearest-point ETA display remains separate and uses the existing weighted-distance calculations. Position stays in memory only; no GPS trail is saved or uploaded. Local tracking and notifications do not require internet access. Offline base-map coverage includes stages 1–5.

## Required real-phone acceptance check

- Grant permissions, start on a valid route and lock the phone for at least 10 minutes. Walk beyond the saved threshold by enough to exceed GPS uncertainty. Confirm one audible/vibrating notification, subject to phone sound/Focus settings.
- Return to the route, wait out cooldown, then depart again. Confirm rearming without repeated alerts while continuously outside.
- Repeat with mobile data disabled, screen locked and battery saver enabled/disabled; record OS/device behavior and battery percentage over a one-hour walk.
- Leave the map for another app screen: Stop remains accessible. Stop and confirm the Android foreground notification / iOS location indicator disappears and no further alerts arrive.
- Deny notification/location permission, disable precise location, turn GPS off mid-session and cancel a permission prompt. Confirm visible errors and no unintended tracking.
- Force-close and reopen: session must remain stopped. Test notifications under silent/Do Not Disturb/Focus; the app does not override those settings.

Automated tests cover geometry, filtering, cooldown/reentry, preference storage, permission cancellation, notification denial, duplicate starts and subscription shutdown. They do not prove physical locked-screen delivery. The Android build on this host remains blocked by Gradle setup; no newly verified APK is included.

References: [geolocator](https://pub.dev/packages/geolocator), [notification plugin setup](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0).
