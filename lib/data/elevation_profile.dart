import 'package:latlong2/latlong.dart';
import 'models.dart' as guide;

class ElevationPoint {
  final int pathId, sequence;
  final double distanceMetres, elevationMetres;
  final LatLng position;
  const ElevationPoint(
    this.pathId,
    this.sequence,
    this.distanceMetres,
    this.elevationMetres,
    this.position,
  );
  factory ElevationPoint.fromRow(guide.Row row) => ElevationPoint(
    guide.integer(row, 'pathID'),
    guide.integer(row, 'sequence'),
    guide.optionalDouble(row, 'distanceAlongPathMetres')!,
    guide.optionalDouble(row, 'elevationMetres')!,
    guide.coordinate(row, 'latitude', 'longitude')!,
  );
}

class ElevationSection {
  final guide.Path path;
  final List<ElevationPoint> points;
  final double offsetMetres;
  const ElevationSection(this.path, this.points, this.offsetMetres);
  double get length => points.isEmpty ? 0 : points.last.distanceMetres;
}

class ElevationMatch {
  final ElevationPoint point;
  final double distanceFromRoute, chartDistance;
  const ElevationMatch(this.point, this.distanceFromRoute, this.chartDistance);
}

/// Distances concatenate sampled portions only. Unsampled joins are never
/// counted as known walking distance or drawn as invented elevation profiles.
class ElevationProfile {
  static const maximumMatchMetres = 200.0;
  // Village coordinates can be offset from an alternative route through it.
  // This allowance applies only to labels on the location's own paths.
  static const maximumLandmarkMetres = 300.0;
  final List<guide.Location> locations;
  final guide.Stage stage;
  final List<ElevationSection> sections;
  final List<int> missingPaths;
  final List<String> issues;
  const ElevationProfile(
    this.stage,
    this.sections,
    this.missingPaths,
    this.issues, {
    this.locations = const [],
  });
  int get sampleCount => sections.fold(0, (sum, s) => sum + s.points.length);
  double get length => sections.fold(0, (sum, s) => sum + s.length);

  List<ElevationLandmark> get landmarks {
    const distance = Distance(roundResult: false);
    final result = <ElevationLandmark>[];
    for (final location in locations) {
      final coordinate = location.position;
      if (coordinate == null) continue;
      ElevationMatch? match;
      for (final section in sections) {
        if (section.path.originLocationId != location.id &&
            section.path.destinationLocationId != location.id) {
          continue;
        }
        for (final point in section.points) {
          final metres = distance(coordinate, point.position);
          if (metres <= maximumLandmarkMetres &&
              (match == null || metres < match.distanceFromRoute)) {
            match = ElevationMatch(
              point,
              metres,
              section.offsetMetres + point.distanceMetres,
            );
          }
        }
      }
      if (match != null) result.add(ElevationLandmark(location, match));
    }
    result.sort(
      (a, b) => a.match.chartDistance.compareTo(b.match.chartDistance),
    );
    return result;
  }

  ElevationMatch? nearest(LatLng position, {double accuracy = 0}) {
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 50 ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite) {
      return null;
    }
    const distance = Distance();
    ElevationMatch? result;
    for (final section in sections) {
      for (final point in section.points) {
        final metres = distance.as(LengthUnit.Meter, position, point.position);
        if (metres <= maximumMatchMetres &&
            (result == null || metres < result.distanceFromRoute)) {
          result = ElevationMatch(
            point,
            metres,
            section.offsetMetres + point.distanceMetres,
          );
        }
      }
    }
    return result;
  }
}

class ElevationLandmark {
  final guide.Location location;
  final ElevationMatch match;
  const ElevationLandmark(this.location, this.match);
}
