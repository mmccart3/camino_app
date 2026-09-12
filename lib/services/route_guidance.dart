import 'package:latlong2/latlong.dart';
import '../data/models.dart';
import 'settings_service.dart';

class RouteGuidance {
  final TrackPoint nearestTrackPoint;
  LatLng get nearestPosition => nearestTrackPoint.position;
  final TrackPoint? nextWaypoint;
  final double offRouteMeters;
  final double? distanceToNextMeters, remainingMeters;
  final Duration? timeToNext, timeRemaining;
  RouteGuidance({
    required this.nearestTrackPoint,
    required this.nextWaypoint,
    required this.offRouteMeters,
    required this.distanceToNextMeters,
    required this.remainingMeters,
    required this.timeToNext,
    required this.timeRemaining,
  });
}

/// Estimates along an ordered route, starting at the nearest stored point.
/// Each row stores the incoming segment from previous_track_point_id.
/// The database's weighted_distance / paceKmh yields seconds (owner convention),
/// so no additional metres/kilometres conversion is applied to that value.
class RouteGuidanceService {
  final Distance _distance = const Distance(roundResult: false);
  RouteGuidance? calculate(
    List<TrackPoint> points,
    LatLng position,
    double paceKmh,
  ) {
    if (!paceKmh.isFinite ||
        paceKmh < SettingsService.minimumPaceKmh ||
        paceKmh > SettingsService.maximumPaceKmh) {
      throw ArgumentError.value(paceKmh, 'paceKmh');
    }
    if (points.isEmpty) return null;
    for (final p in [position, ...points.map((p) => p.position)]) {
      if (!p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180) {
        throw ArgumentError('Invalid route coordinate');
      }
    }
    var nearestIndex = 0;
    var offset = _distance(position, points.first.position);
    for (var i = 1; i < points.length; i++) {
      final distance = _distance(position, points[i].position);
      if (distance < offset) {
        nearestIndex = i;
        offset = distance;
      }
    }
    // Null means unavailable; missing/negative values must not become zero
    // or be silently replaced by horizontal geometry.
    double? sumTo(int end, double? Function(TrackPoint) metric) {
      var sum = 0.0;
      for (var i = nearestIndex + 1; i <= end; i++) {
        final value = metric(points[i]);
        if (value == null || !value.isFinite || value < 0) return null;
        sum += value;
      }
      return sum.isFinite ? sum : null;
    }

    int? nextIndex;
    for (var i = nearestIndex + 1; i < points.length; i++) {
      if (points[i].isWaypoint ||
          points[i].waypointName != null ||
          i == points.length - 1) {
        // A repeated path-boundary waypoint with zero intervening distance
        // is already reached, rather than the next place ahead.
        if (i != points.length - 1 &&
            sumTo(i, (p) => p.distance3dMeters) == 0 &&
            _distance(points[nearestIndex].position, points[i].position) <
                0.01) {
          continue;
        }
        nextIndex = i;
        break;
      }
    }
    Duration? eta(double? weighted) => weighted == null
        ? null
        : Duration(
            microseconds: (weighted / paceKmh * Duration.microsecondsPerSecond)
                .round(),
          );
    return RouteGuidance(
      nearestTrackPoint: points[nearestIndex],
      nextWaypoint: nextIndex == null ? null : points[nextIndex],
      offRouteMeters: offset,
      distanceToNextMeters: sumTo(
        nextIndex ?? nearestIndex,
        (p) => p.distance3dMeters,
      ),
      remainingMeters: sumTo(points.length - 1, (p) => p.distance3dMeters),
      timeToNext: eta(
        sumTo(nextIndex ?? nearestIndex, (p) => p.weightedDistance),
      ),
      timeRemaining: eta(sumTo(points.length - 1, (p) => p.weightedDistance)),
    );
  }
}
