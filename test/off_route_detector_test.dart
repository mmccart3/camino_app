import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:camino_app/services/off_route_detector.dart';

void main() {
  final route = [const LatLng(42, -1), const LatLng(42, -0.99)];
  final origin = DateTime.utc(2026, 9, 12);
  test(
    'segment projection handles midpoint, endpoints and duplicate points',
    () {
      expect(distanceToRoute(const LatLng(42, -0.995), route), closeTo(0, .01));
      expect(
        distanceToRoute(const LatLng(42.001, -0.995), route),
        closeTo(111.2, .2),
      );
      expect(
        distanceToRoute(const LatLng(42, -1.001), route),
        closeTo(82.6, .3),
      );
      expect(
        distanceToRoute(const LatLng(42, -1), [route.first, route.first]),
        0,
      );
    },
  );
  test('three fixes over ten seconds, reentry and two-minute cooldown', () {
    final d = OffRouteDetector(route, 50);
    bool fix(int seconds, {LatLng point = const LatLng(42.001, -0.995)}) {
      final t = origin.add(Duration(seconds: seconds));
      return d.sample(point, 5, t, t);
    }

    expect(fix(0), false);
    expect(fix(5), false);
    expect(fix(10), true);
    expect(fix(20), false);
    expect(fix(30, point: const LatLng(42, -0.995)), false);
    expect(fix(35), false);
    expect(fix(40), false);
    expect(fix(45), false);
    expect(fix(120), false);
    expect(fix(125), false);
    expect(fix(130), true);
  });
  test('poor, stale, duplicate and future fixes cannot trigger alerts', () {
    final d = OffRouteDetector(route, 50);
    const p = LatLng(42.001, -0.995);
    expect(d.sample(p, 80, origin, origin), false);
    expect(
      d.sample(p, 5, origin, origin.add(const Duration(minutes: 2))),
      false,
    );
    expect(
      d.sample(p, 5, origin.add(const Duration(minutes: 2)), origin),
      false,
    );
    expect(d.sample(p, 5, origin, origin), false);
    for (var i = 0; i < 5; i++) {
      expect(d.sample(p, 5, origin, origin), false);
    }
    final next = origin.add(const Duration(seconds: 10));
    expect(d.sample(p, 5, next, next), false);
    final last = origin.add(const Duration(seconds: 15));
    expect(d.sample(p, 5, last, last), true);
  });
  test('GPS uncertainty and brief excursions are tolerated', () {
    final d = OffRouteDetector(route, 50);
    for (var i = 0; i < 4; i++) {
      final t = origin.add(Duration(seconds: i * 5));
      expect(d.sample(const LatLng(42.0005, -0.995), 15, t, t), false);
    }
    for (var i = 4; i < 8; i++) {
      final t = origin.add(Duration(seconds: i * 5));
      expect(d.sample(LatLng(i.isEven ? 42.001 : 42, -0.995), 5, t, t), false);
    }
  });
  test('invalid thresholds and empty routes fail explicitly', () {
    expect(() => OffRouteDetector(route, double.nan), throwsArgumentError);
    expect(() => OffRouteDetector(route, 10), throwsArgumentError);
    expect(() => OffRouteDetector([], 50), throwsArgumentError);
  });
}
