# Automatic position updates (0.2.88+93)

Both route maps offer Automatic position updates (off initially), Update interval (30 seconds, 1, 2, 5 or 10 minutes; default 2 minutes), and Keep map centred on me (off initially). Preferences are stored on the device. Update my position remains available and the most recent fix timestamp is shown.

Enabling automatic updates requests a fix immediately, then at the selected interval. Changing settings or returning to the map refreshes the schedule. Refreshes pause when the app is hidden, locked, or the map route is offstage. An already pending fix is ignored if the screen becomes hidden or settings change. Requests never overlap, and failures retain the last recorded position with an error message.

An active walking-alert session supplies its existing position updates even with automatic refresh switched off. This avoids an extra GPS request and does not change the off-route detection interval or background-alert settings. Location destination navigation now uses these controls instead of an unconditional GPS stream. Shorter intervals consume more battery. Arrival confirmation still requires a recent, accurate fix.

Keep map centred on me follows each received fix without changing zoom or compass orientation. Switch it off to explore the map without automatic recentring. Compass-up remains independent.

Version 0.2.89: the refresh and centring settings are now under Navigation options, alongside stage walking-alert controls. The manual refresh and last-fix timestamp remain visible. Collapsing options does not dispose the foreground refresh controller. Both navigation screens now use a larger responsive map, a wrapping next-stop summary, and expandable route details inside a safe-area scroll view.
