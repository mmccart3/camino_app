param(
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'

$adbTarget = if ($DeviceId) { @('-s', $DeviceId) } else { @() }
$apkPath = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-debug.apk'

Write-Host 'Cleaning previous build...'
flutter clean

Write-Host 'Fetching dependencies...'
flutter pub get

Write-Host 'Building current debug APK...'
flutter build apk --debug

if (-not (Test-Path $apkPath)) {
    throw "APK was not created: $apkPath"
}

Write-Host 'Installing APK on the phone...'
& adb @adbTarget install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    throw 'adb install failed.'
}

Write-Host 'Launching app...'
& adb @adbTarget shell monkey -p com.example.camino_app 1
if ($LASTEXITCODE -ne 0) {
    throw 'Could not launch the app.'
}

Write-Host 'Done.'