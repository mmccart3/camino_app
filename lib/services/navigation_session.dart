import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_assembler.dart';
import 'off_route_detector.dart';
import 'route_notifications.dart';

/// App-owned session: leaving a map does not dispose the GPS subscription.
/// Never auto-starts after launching or restarting the app.
class NavigationSession extends ChangeNotifier {
  static final instance = NavigationSession();
  NavigationSession({
    RouteNotifications? notifications,
    Future<void> Function()? permissionCheck,
    Stream<Position> Function(LocationSettings)? positionStream,
    Stream<ServiceStatus> Function()? serviceStream,
    bool? mobileSupported,
  }) : notifications = notifications ?? RouteNotifications(),
       _permissionCheck = permissionCheck,
       _positionStream =
           positionStream ??
           ((settings) =>
               Geolocator.getPositionStream(locationSettings: settings)),
       _serviceStream = serviceStream ?? Geolocator.getServiceStatusStream,
       _mobileSupported = mobileSupported;
  final RouteNotifications notifications;
  final Future<void> Function()? _permissionCheck;
  final Stream<Position> Function(LocationSettings) _positionStream;
  final Stream<ServiceStatus> Function() _serviceStream;
  final bool? _mobileSupported;
  bool get supported =>
      _mobileSupported ?? (Platform.isAndroid || Platform.isIOS);
  bool stopping = false;
  StreamSubscription<Position>? _positions;
  StreamSubscription<ServiceStatus>? _services;
  Timer? _watchdog;
  OffRouteDetector? _detector;
  bool starting = false, active = false;
  int _generation = 0;
  int? stageId;
  String stageName = '', status = '';
  Position? position;
  DateTime? _lastReceived;
  bool _lostFix = false;
  double get threshold => _detector?.threshold ?? 50;

  Future<void> start(StageRoute route, double metres) async {
    if (!supported) {
      throw UnsupportedError(
        'Screen-locked alerts are available on Android and iPhone.',
      );
    }
    if (active || starting || stopping) {
      throw StateError('Stop the current walking session first.');
    }
    if (!route.canGuide) {
      throw StateError(
        'This stage needs a complete validated route before alerts can start.',
      );
    }
    final token = ++_generation;
    starting = true;
    status = 'Checking permissions…';
    notifyListeners();
    try {
      await (_permissionCheck ?? _checkPermissions)();
      if (token != _generation) return;
      await notifications.prepare();
      if (token != _generation) return;
      _detector = OffRouteDetector(
        route.points.map((p) => p.position).toList(),
        metres,
      );
      stageId = route.stage.id;
      stageName = route.stage.name;
      position = null;
      _lastReceived = DateTime.now();
      _lostFix = false;
      active = true;
      status = 'Waiting for an accurate GPS position…';
      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 5),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Camino walking alerts active',
                notificationText:
                    'GPS uses significant battery. Open Camino to stop.',
                enableWakeLock: true,
              ),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              activityType: ActivityType.fitness,
              pauseLocationUpdatesAutomatically: false,
              allowBackgroundLocationUpdates: true,
              showBackgroundLocationIndicator: true,
            );
      _positions = _positionStream(settings).listen(
        (fix) => _onPosition(fix, token),
        onError: (Object error) =>
            unawaited(_fail('GPS stopped: $error', token)),
        onDone: () => unawaited(
          _fail('GPS stream ended. Restart walking alerts.', token),
        ),
      );
      _services = _serviceStream().listen(
        (value) {
          if (value == ServiceStatus.disabled) {
            unawaited(
              _fail(
                'Location was switched off. Walking alerts stopped.',
                token,
              ),
            );
          }
        },
        onError: (Object error) =>
            unawaited(_fail('Cannot monitor location services: $error', token)),
      );
      _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
        if (active &&
            !_lostFix &&
            DateTime.now().difference(_lastReceived!).inSeconds > 60) {
          _lostFix = true;
          _detector?.resetEvidence();
          status =
              'No recent accurate GPS fix. Off-route detection is waiting.';
          notifyListeners();
          unawaited(_notify('Camino: GPS unavailable', status, token));
        }
      });
    } catch (error) {
      if (token == _generation) await stop(message: '$error');
      rethrow;
    } finally {
      if (token == _generation) {
        starting = false;
        notifyListeners();
      }
    }
  }

  Future<void> _checkPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on phone location services.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError(
        'Allow precise location in app settings before starting navigation.',
      );
    }
    // iOS Always authorization avoids relying on a temporary foreground grant.
    if (Platform.isIOS && permission != LocationPermission.always) {
      throw StateError(
        'In iPhone Settings > Camino > Location choose Always and enable Precise Location, then start again.',
      );
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      throw StateError(
        'Enable precise location in phone settings for reliable off-route alerts.',
      );
    }
  }

  void _onPosition(Position fix, int token) {
    if (!active || token != _generation) return;
    final now = DateTime.now();
    final valid =
        fix.accuracy.isFinite &&
        fix.accuracy >= 0 &&
        fix.accuracy <= (threshold / 2).clamp(0, 50) &&
        now.difference(fix.timestamp).inSeconds <= 30 &&
        !fix.timestamp.isAfter(now.add(const Duration(seconds: 5))) &&
        (position == null || fix.timestamp.isAfter(position!.timestamp));
    final alert = _detector!.sample(
      LatLng(fix.latitude, fix.longitude),
      fix.accuracy,
      fix.timestamp,
      now,
    );
    if (valid) {
      position = fix;
      _lastReceived = now;
      _lostFix = false;
      status =
          '${_detector!.distance!.round()} m from route · GPS ±${fix.accuracy.round()} m';
    } else {
      status =
          'Waiting for a fresh, accurate GPS fix. Off-route detection is paused.';
    }
    notifyListeners();
    if (alert) {
      unawaited(
        _notify(
          'You may be off route',
          'About ${_detector!.distance!.round()} metres from the $stageName track. Check the map when safe.',
          token,
        ),
      );
    }
  }

  Future<void> _notify(String title, String message, int token) async {
    if (token != _generation || !active) return;
    try {
      await notifications.show(title, message);
    } catch (error) {
      if (token == _generation) {
        await stop(
          message: 'Notifications failed. Walking alerts stopped: $error',
        );
      }
    }
  }

  Future<void> _fail(String message, int token) async {
    if (!active || token != _generation) return;
    try {
      await notifications.show('Camino walking alerts stopped', message);
    } catch (_) {
      /* Status remains visible in app. */
    }
    if (token == _generation) {
      await stop(message: message, clearNotification: false);
    }
  }

  Future<void> stop({
    String message = 'Walking alerts stopped.',
    bool clearNotification = true,
  }) async {
    if (stopping) return;
    stopping = true;
    ++_generation;
    active = false;
    starting = false;
    _watchdog?.cancel();
    _watchdog = null;
    final positions = _positions, services = _services;
    _positions = null;
    _services = null;
    status = message;
    notifyListeners();
    try {
      try {
        await positions?.cancel();
      } finally {
        await services?.cancel();
      }
      if (clearNotification) {
        try {
          await notifications.clear();
        } catch (_) {
          /* GPS is stopped. */
        }
      }
    } catch (error) {
      status =
          'Could not confirm GPS shutdown. Close the app to stop tracking: $error';
    } finally {
      stopping = false;
      notifyListeners();
    }
  }
}
