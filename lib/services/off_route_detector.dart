import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Short segments in Camino routes are projected into a local metre grid.
/// Clamping the projection also handles endpoints and repeated coordinates.
double distanceToRoute(LatLng point, List<LatLng> route) {
  if (route.length < 2) throw ArgumentError('A route needs two points.');
  const radius = 6371000.0;
  final scale = math.pi / 180 * radius;
  final cosLatitude = math.cos(point.latitude * math.pi / 180);
  var nearest = double.infinity;
  for (var i = 1; i < route.length; i++) {
    final a = route[i - 1], b = route[i];
    final ax = (a.longitude - point.longitude) * scale * cosLatitude;
    final ay = (a.latitude - point.latitude) * scale;
    final bx = (b.longitude - point.longitude) * scale * cosLatitude;
    final by = (b.latitude - point.latitude) * scale;
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    nearest = math.min(
      nearest,
      math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2)),
    );
  }
  return nearest;
}

class OffRouteDetector {
  final List<LatLng> route;
  final double threshold;
  OffRouteDetector(List<LatLng> route, this.threshold)
    : route = List.unmodifiable(route) {
    if (route.length < 2 ||
        !threshold.isFinite ||
        threshold < 20 ||
        threshold > 500) {
      throw ArgumentError('Choose a valid route and a threshold of 20–500 m.');
    }
  }
  DateTime? _lastFix, _outsideSince, _lastAlert;
  int _outsideCount = 0;
  bool _latched = false;
  double? distance;
  void resetEvidence() {
    _outsideSince = null;
    _outsideCount = 0;
  }

  /// Three distinct accurate readings spanning ten seconds; one alert per
  /// excursion. Rearm only after returning clearly inside, with a 2 min cooldown.
  bool sample(LatLng point, double accuracy, DateTime timestamp, DateTime now) {
    if (_lastFix != null && !timestamp.isAfter(_lastFix!)) return false;
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > math.min(50, threshold / 2) ||
        now.difference(timestamp).inSeconds > 30 ||
        timestamp.isAfter(now.add(const Duration(seconds: 5)))) {
      resetEvidence();
      return false;
    }
    if (_lastFix != null && timestamp.difference(_lastFix!).inSeconds > 30) {
      resetEvidence();
    }
    _lastFix = timestamp;
    distance = distanceToRoute(point, route);
    if (distance! + accuracy < threshold * .7) {
      _latched = false;
      resetEvidence();
      return false;
    }
    if (distance! - accuracy <= threshold) {
      resetEvidence();
      return false;
    }
    _outsideSince ??= timestamp;
    _outsideCount++;
    if (_latched ||
        _outsideCount < 3 ||
        timestamp.difference(_outsideSince!).inSeconds < 10 ||
        (_lastAlert != null && now.difference(_lastAlert!).inSeconds < 120)) {
      return false;
    }
    _latched = true;
    _lastAlert = now;
    return true;
  }
}
