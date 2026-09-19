import '../data/models.dart';
import '../data/route_assembler.dart';
import 'settings_service.dart';

class AheadPlace {
  final Location location;
  final double? metres;
  final Duration? walkingTime;
  const AheadPlace(this.location, this.metres, this.walkingTime);
}

/// Path destinations determine which places are ahead. Distances are incoming
/// track metrics after the nearest point, never straight-line village distances.
class AheadOfMeService {
  List<AheadPlace> calculate(StageRoute route, int nearestIndex, double pace) {
    if (!route.canGuide) return [];
    if (!pace.isFinite ||
        pace < SettingsService.minimumPaceKmh ||
        pace > SettingsService.maximumPaceKmh) {
      throw ArgumentError.value(pace, 'pace');
    }
    if (nearestIndex < 0 || nearestIndex >= route.points.length) {
      throw RangeError.index(nearestIndex, route.points);
    }
    final destinations = {
      for (final path in route.paths) path.id: path.destinationLocationId,
    };
    final lastIndices = <int, int>{};
    for (var i = 0; i < route.points.length; i++) {
      lastIndices[route.points[i].pathId] = i;
    }
    final locations = {
      for (final location in route.locations) location.id: location,
    };
    final result = <AheadPlace>[], seen = <int>{};
    double? metres = 0, weighted = 0;
    double? add(double? total, double? value) =>
        total == null ||
            value == null ||
            !value.isFinite ||
            value < 0 ||
            !(total + value).isFinite
        ? null
        : total + value;
    for (var i = nearestIndex + 1; i < route.points.length; i++) {
      final point = route.points[i];
      metres = add(metres, point.distance3dMeters);
      weighted = add(weighted, point.weightedDistance);
      if (lastIndices[point.pathId] != i) continue;
      final location = locations[destinations[point.pathId]];
      if (location == null || !seen.add(location.id)) continue;
      if (metres == 0) continue; // Repeated boundary already reached.
      result.add(
        AheadPlace(
          location,
          metres,
          weighted == null
              ? null
              : Duration(
                  microseconds:
                      (weighted / pace * Duration.microsecondsPerSecond)
                          .round(),
                ),
        ),
      );
    }
    return result;
  }
}
