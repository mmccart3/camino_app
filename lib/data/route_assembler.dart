import 'package:latlong2/latlong.dart' show Distance;
import 'models.dart';

class RouteDataException implements Exception {
  final String message;
  RouteDataException(this.message);
  @override
  String toString() => message;
}

class StageRoute {
  final Stage stage;
  final List<Path> paths;
  final List<Location> locations;

  /// Separate segments may be rendered even when full guidance is unavailable.
  final List<List<TrackPoint>> segments;
  final List<TrackPoint> points;
  final List<String> issues;
  final bool locationsOrdered;
  bool get canGuide => issues.isEmpty && points.length >= 2;
  StageRoute({
    required this.stage,
    required this.paths,
    required this.locations,
    required this.segments,
    required this.points,
    required this.issues,
    required this.locationsOrdered,
  });
}

/// Orders graph edges from the declared stage start to the declared finish.
/// Never guesses which branch to take or substitutes location-to-location lines.
class RouteAssembler {
  static List<Path> orderPaths(Stage stage, List<Path> paths) {
    if (paths.isEmpty) {
      throw RouteDataException('No paths are available for this stage.');
    }
    final result = <Path>[], used = <int>{};
    var current = stage.startLocationId;
    while (current != stage.finishLocationId) {
      final candidates = paths
          .where((p) => p.originLocationId == current)
          .toList();
      if (candidates.isEmpty) {
        throw RouteDataException('Route is incomplete at location $current.');
      }
      if (candidates.length != 1) {
        throw RouteDataException(
          'Route has multiple paths from location $current; its order needs review.',
        );
      }
      final path = candidates.single;
      if (!used.add(path.id)) {
        throw RouteDataException('Route contains a cycle at path ${path.id}.');
      }
      result.add(path);
      current = path.destinationLocationId;
    }
    if (result.length != paths.length) {
      throw RouteDataException(
        'Stage contains disconnected or alternative paths; its order needs review.',
      );
    }
    return result;
  }

  /// A path head may refer to the previous path's final track point.
  /// Within each path there must be exactly one predecessor chain.
  static List<TrackPoint> orderPoints(List<TrackPoint> rows) {
    if (rows.isEmpty) {
      return [];
    }
    final byId = {for (final p in rows) p.id: p};
    if (byId.length != rows.length) {
      throw RouteDataException('Duplicate track point IDs.');
    }
    final heads = rows
        .where((p) => !byId.containsKey(p.previousTrackPointId))
        .toList();
    if (heads.length != 1) {
      throw RouteDataException(
        'Track point chain has missing links or a cycle.',
      );
    }
    final next = <int, TrackPoint>{};
    for (final point in rows) {
      final prior = point.previousTrackPointId;
      if (prior != null && byId.containsKey(prior)) {
        if (next.containsKey(prior)) {
          throw RouteDataException('Track point chain branches at $prior.');
        }
        next[prior] = point;
      }
    }
    final result = <TrackPoint>[], visited = <int>{};
    TrackPoint? current = heads.single;
    while (current != null) {
      if (!visited.add(current.id)) {
        throw RouteDataException('Track point chain contains a cycle.');
      }
      result.add(current);
      current = next[current.id];
    }
    if (result.length != rows.length) {
      throw RouteDataException('Track point chain is disconnected.');
    }
    return result;
  }

  static StageRoute assemble(
    Stage stage,
    List<Path> paths,
    List<Location> locations,
    Map<int, List<TrackPoint>> tracks, {
    List<String> trackIssues = const [],
  }) {
    final issues = <String>[...trackIssues];
    List<Path> ordered;
    var locationsOrdered = true;
    try {
      ordered = orderPaths(stage, paths);
    } on RouteDataException catch (error) {
      ordered = paths;
      locationsOrdered = false;
      issues.add(error.message);
    }
    final byLocation = {
      for (final location in locations) location.id: location,
    };
    final ids = <int>{
      stage.startLocationId,
      for (final path in ordered) ...[
        path.originLocationId,
        path.destinationLocationId,
      ],
      stage.finishLocationId,
    };
    if (ids.any((id) => !byLocation.containsKey(id))) {
      issues.add('Some route locations are missing from the database.');
    }
    final displayLocations = [
      for (final id in ids)
        if (byLocation[id] != null) byLocation[id]!,
    ];
    final segments = <List<TrackPoint>>[], points = <TrackPoint>[];
    var missing = 0;
    const distance = Distance(roundResult: false);
    for (final path in ordered) {
      final rows = tracks[path.id] ?? [];
      if (rows.length < 2) {
        missing++;
        if (rows.isNotEmpty) {
          segments.add(rows);
        }
        continue;
      }
      final named = <TrackPoint>[];
      for (var i = 0; i < rows.length; i++) {
        var point = rows[i];
        if (point.isWaypoint) {
          final label = i == 0
              ? byLocation[path.originLocationId]?.name
              : i == rows.length - 1
              ? byLocation[path.destinationLocationId]?.name
              : null;
          point = point.named(label ?? 'Waypoint ${point.id}');
        }
        named.add(point);
      }
      segments.add(named);
      if (points.isNotEmpty) {
        final head = named.first;
        final predecessor = head.previousTrackPointId;
        if (predecessor != null &&
            predecessor != 0 &&
            predecessor != points.last.id) {
          issues.add(
            'Path ${path.id} does not follow the previous track point chain.',
          );
        }
        if (distance(points.last.position, head.position) > 150) {
          issues.add('Track geometry has a gap before path ${path.id}.');
        }
      }
      for (var i = 1; i < named.length; i++) {
        if (distance(named[i - 1].position, named[i].position) > 250) {
          issues.add(
            'Path ${path.id} contains a track gap greater than 250 m.',
          );
          break;
        }
      }
      points.addAll(named);
    }
    if (missing > 0) {
      issues.add(
        'Track points are missing or incomplete for $missing of ${paths.length} paths. Full-stage guidance is unavailable.',
      );
    }
    if (points.isNotEmpty && locationsOrdered) {
      final start = byLocation[stage.startLocationId]?.position,
          end = byLocation[stage.finishLocationId]?.position;
      if (start == null ||
          end == null ||
          distance(start, points.first.position) > 150 ||
          distance(end, points.last.position) > 150) {
        issues.add(
          'Track geometry does not reach both declared stage endpoints.',
        );
      }
      points[points.length - 1] = points.last.named(
        byLocation[stage.finishLocationId]?.name ?? 'Stage end',
      );
    }
    return StageRoute(
      stage: stage,
      paths: List.unmodifiable(ordered),
      locations: List.unmodifiable(displayLocations),
      segments: List.unmodifiable(
        segments.map((s) => List<TrackPoint>.unmodifiable(s)),
      ),
      points: List.unmodifiable(points),
      issues: List.unmodifiable(issues.toSet()),
      locationsOrdered: locationsOrdered,
    );
  }
}
