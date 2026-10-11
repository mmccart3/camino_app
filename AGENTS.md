# Project instructions

## Versioning

The user requests automatic patch-version and build-number increments for completed app updates.
- In `pubspec.yaml`, increment both the patch component (the third number before `+`) and the build number after `+` once per completed user-requested app update (including bundled content/database changes). For example: `0.3.1+107` becomes `0.3.2+108`.
- Keep the major and minor components unchanged unless the user requests a different release version.
- Increment once for the whole update, not for each edited file, intermediate fix, test run, or platform build. Read the current value first; never reset or decrease it.
- Do not increment for read-only questions, reviews, or website-only changes.
- Report the resulting version and build number when delivering an update. Source changes require a new build/install to appear on a device.
