import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/services/walking_time.dart';

void main() {
  test('5.1 km on flat ground at 5.1 km/h takes one hour', () {
    final weight = 5100 * 3.6 / math.exp(-2.25 * 0.07);
    expect(WalkingTime.estimate(weight, 5.1), const Duration(hours: 1));
  });
  test('uphill takes longer and optimal downhill takes less time', () {
    final flat = WalkingTime.estimate(5100 * 3.6 / math.exp(-0.1575), 5.1)!;
    final uphill = WalkingTime.estimate(
      5100 * 3.6 / math.exp(-2.25 * 0.17),
      5.1,
    )!;
    final downhill = WalkingTime.estimate(5100 * 3.6, 5.1)!;
    expect(uphill, greaterThan(flat));
    expect(downhill, lessThan(flat));
    expect(WalkingTime.estimate(null, 5.1), isNull);
  });
}
