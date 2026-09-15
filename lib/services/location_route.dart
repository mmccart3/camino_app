import 'package:latlong2/latlong.dart';
import '../data/models.dart';
import '../data/route_assembler.dart';

class LocationRoute {
  final List<TrackPoint> points;
  final double destinationOffset;
  final bool reversed;
  const LocationRoute(this.points, this.destinationOffset, this.reversed);
}

class _Edge {
  final int to;
  final double length;
  final double? metres, weighted;
  final bool reversed;
  _Edge(this.to, this.length, this.metres, this.weighted, this.reversed);
}

/// Uses validated predecessor chains only. No inferred road connections.
class LocationRoutePlanner {
  static const distance = Distance(roundResult: false);
  static LocationRoute? plan(
    List<StageRoute> routes,
    Location destination,
    LatLng user,
  ) {
    final target = destination.position;
    if (target == null) return null;
    final nodes = <int, TrackPoint>{};
    final edges = <int, List<_Edge>>{};
    final ends = <int, List<int>>{};
    final starts = <int, List<int>>{};
    final targets = <int>{};
    void connect(TrackPoint a, TrackPoint b, double? metres, double? weighted) {
      final length = distance(a.position, b.position);
      edges
          .putIfAbsent(a.id, () => [])
          .add(_Edge(b.id, length, metres, weighted, false));
      edges
          .putIfAbsent(b.id, () => [])
          .add(_Edge(a.id, length, metres, weighted, true));
    }

    for (final route in routes) {
      for (final segment in route.segments) {
        if (segment.length < 2) continue;
        if (List.generate(
          segment.length - 1,
          (i) => distance(segment[i].position, segment[i + 1].position),
        ).any((d) => d > 250)) {
          continue;
        }
        final matching = route.paths.where((p) => p.id == segment.first.pathId);
        if (matching.length != 1) continue;
        final path = matching.single;
        for (final p in segment) {
          nodes[p.id] = p;
        }
        for (var i = 1; i < segment.length; i++) {
          connect(
            segment[i - 1],
            segment[i],
            segment[i].distance3dMeters,
            segment[i].weightedDistance,
          );
        }
        starts
            .putIfAbsent(path.originLocationId, () => [])
            .add(segment.first.id);
        ends
            .putIfAbsent(path.destinationLocationId, () => [])
            .add(segment.last.id);
        if (path.originLocationId == destination.id) {
          targets.add(segment.first.id);
        }
        if (path.destinationLocationId == destination.id) {
          targets.add(segment.last.id);
        }
      }
    }
    // Join only paths sharing a declared location and a geometrically close,
    // compatible predecessor boundary. Unmeasured connectors have unknown ETA.
    for (final entry in ends.entries) {
      for (final a in entry.value) {
        for (final b in starts[entry.key] ?? <int>[]) {
          final first = nodes[a]!, second = nodes[b]!;
          final prior = second.previousTrackPointId;
          final gap = distance(first.position, second.position);
          if (a != b &&
              gap <= 150 &&
              (prior == null || prior == 0 || prior == a)) {
            connect(
              first,
              second,
              gap < 0.01
                  ? 0
                  : prior == a
                  ? second.distance3dMeters
                  : null,
              gap < 0.01
                  ? 0
                  : prior == a
                  ? second.weightedDistance
                  : null,
            );
          }
        }
      }
    }
    targets.removeWhere((id) => distance(nodes[id]!.position, target) > 150);
    if (nodes.isEmpty || targets.isEmpty) return null;
    final start = nodes.values.reduce(
      (a, b) =>
          distance(user, a.position) <= distance(user, b.position) ? a : b,
    );
    // An offline basemap is not a road router to a distant Camino track.
    if (distance(user, start.position) > 150) return null;
    final costs = <int, double>{start.id: 0};
    final pending = <int>{start.id}, visited = <int>{};
    final previous = <int, (int, _Edge)>{};
    int? finish;
    while (pending.isNotEmpty) {
      final current = pending.reduce((a, b) => costs[a]! <= costs[b]! ? a : b);
      pending.remove(current);
      if (targets.contains(current)) {
        finish = current;
        break;
      }
      visited.add(current);
      for (final edge in edges[current] ?? <_Edge>[]) {
        if (visited.contains(edge.to)) continue;
        final cost = costs[current]! + edge.length;
        if (cost < (costs[edge.to] ?? double.infinity)) {
          costs[edge.to] = cost;
          previous[edge.to] = (current, edge);
          pending.add(edge.to);
        }
      }
    }
    if (finish == null) return null;
    final ids = <int>[finish];
    while (ids.last != start.id) {
      ids.add(previous[ids.last]!.$1);
    }
    final ordered = ids.reversed.toList();
    var reversed = false;
    final points = <TrackPoint>[];
    for (var i = 0; i < ordered.length; i++) {
      final original = nodes[ordered[i]]!;
      final edge = i == 0 ? null : previous[ordered[i]]!.$2;
      reversed = reversed || (edge?.reversed ?? false);
      points.add(
        TrackPoint.fromRow(
          {
            ...original.source,
            'distance_3d_meters': edge?.metres,
            '3D-Distance': edge?.metres,
            'weighted_distance': edge?.weighted,
            'previous_track_point_id': i == 0 ? null : ordered[i - 1],
          },
          waypointName: i == ordered.length - 1
              ? destination.name
              : original.waypointName,
        ),
      );
    }
    return LocationRoute(
      points,
      distance(points.last.position, target),
      reversed,
    );
  }
}
