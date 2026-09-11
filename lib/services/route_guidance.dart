import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../data/models.dart';

class RouteGuidance {
  final LatLng nearestPosition;
  final TrackPoint? nextWaypoint;
  final double offRouteMeters, distanceToNextMeters, remainingMeters;
  final Duration timeToNext, timeRemaining;
  RouteGuidance({
    required this.nearestPosition,
    required this.nextWaypoint,
    required this.offRouteMeters,
    required this.distanceToNextMeters,
    required this.remainingMeters,
    required this.timeToNext,
    required this.timeRemaining,
  });
}

/// Stateless geometric guidance for one validated, assembled stage route.
/// ETAs exclude rest, terrain and the distance needed to rejoin the route.
class RouteGuidanceService {
  final Distance _distance = const Distance(roundResult: false);
  RouteGuidance? calculate(
    List<TrackPoint> points,
    LatLng position,
    double paceKmh,
  ) {
    if (!paceKmh.isFinite || paceKmh <= 0) {
      throw ArgumentError.value(paceKmh, 'paceKmh');
    }
    if (points.isEmpty) {
      return null;
    }
    for (final p in [position, ...points.map((p) => p.position)]) {
      if (!p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180) {
        throw ArgumentError('Invalid route coordinate');
      }
    }
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(
        cumulative.last + _distance(points[i - 1].position, points[i].position),
      );
    }
    var nearest = points.first.position;
    var offset = _distance(position, nearest);
    var progress = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position, b = points[i + 1].position;
      final scale = math.cos(position.latitude * math.pi / 180);
      final dx = (b.longitude - a.longitude) * scale;
      final dy = b.latitude - a.latitude;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (((position.longitude - a.longitude) * scale * dx +
                        (position.latitude - a.latitude) * dy) /
                    lengthSquared)
                .clamp(0.0, 1.0);
      final projected = LatLng(
        a.latitude + dy * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final distance = _distance(position, projected);
      if (distance < offset) {
        offset = distance;
        nearest = projected;
        progress = cumulative[i] + (cumulative[i + 1] - cumulative[i]) * t;
      }
    }
    int? nextIndex;
    for (var i = 0; i < points.length; i++) {
      if (cumulative[i] > progress + 0.5 &&
          (points[i].isWaypoint ||
              points[i].waypointName != null ||
              i == points.length - 1)) {
        nextIndex = i;
        break;
      }
    }
    final remaining = math.max(0.0, cumulative.last - progress);
    final toNext = nextIndex == null ? 0.0 : cumulative[nextIndex] - progress;
    Duration eta(double meters) =>
        Duration(seconds: (meters / (paceKmh / 3.6)).round());
    return RouteGuidance(
      nearestPosition: nearest,
      nextWaypoint: nextIndex == null ? null : points[nextIndex],
      offRouteMeters: offset,
      distanceToNextMeters: toNext,
      remainingMeters: remaining,
      timeToNext: eta(toNext),
      timeRemaining: eta(remaining),
    );
  }
}
