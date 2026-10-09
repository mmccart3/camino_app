import 'dart:math' as math;

/// Stored weights are metres * 3.6 / slopeEffect. Normalize to the
/// effect at zero gradient so the chosen speed is true flat-ground km/h.
class WalkingTime {
  static String format(Duration duration) {
    final minutes = (duration.inMicroseconds / Duration.microsecondsPerMinute)
        .ceil();
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  static final double flatSlopeEffect = math.exp(-2.25 * 0.07);

  static Duration? estimate(double? weightedDistance, double flatSpeedKmh) {
    if (!flatSpeedKmh.isFinite || flatSpeedKmh <= 0) {
      throw ArgumentError.value(flatSpeedKmh, 'flatSpeedKmh');
    }
    if (weightedDistance == null ||
        !weightedDistance.isFinite ||
        weightedDistance < 0) {
      return null;
    }
    return Duration(
      microseconds:
          (weightedDistance *
                  flatSlopeEffect /
                  flatSpeedKmh *
                  Duration.microsecondsPerSecond)
              .round(),
    );
  }
}
