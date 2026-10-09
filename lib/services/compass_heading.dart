import 'dart:math' as math;

/// Circular smoothing avoids a full-circle jump when crossing north.
class CompassHeading {
  double? degrees;
  double update(double value) {
    if (!value.isFinite) throw ArgumentError.value(value, 'value');
    final normalized = value % 360;
    final previous = degrees;
    degrees = previous == null
        ? normalized
        : (previous + ((normalized - previous + 540) % 360 - 180) * 0.3) % 360;
    return degrees!;
  }

  void reset() => degrees = null;
  static double radians(double degrees) => degrees * math.pi / 180;
  static String direction(double degrees) => const [
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
  ][((degrees % 360 + 22.5) / 45).floor() % 8];
}
