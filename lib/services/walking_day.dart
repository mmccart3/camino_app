import '../data/walking_location_order.dart';
import 'package:latlong2/latlong.dart' show Distance;
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../data/elevation_profile.dart';
import 'walking_time.dart';

class DayLeg {
  final Path path;
  final List<TrackPoint> points;
  const DayLeg(this.path, this.points);
}

class WalkingDay {
  final List<DayLeg> legs;
  final List<Location> places;
  final double metres, ascent, descent, joinMetres;
  final Duration walkingTime;
  final List<Duration> arrivalOffsets;
  final ElevationProfile profile;
  const WalkingDay(
    this.legs,
    this.places,
    this.metres,
    this.ascent,
    this.descent,
    this.joinMetres,
    this.walkingTime,
    this.profile,
    this.arrivalOffsets,
  );
  String get name => '${places.first.name} to ${places.last.name}';

  DayTimetable timetable(Map<int, int> breakMinutes) {
    final arrivals = <Duration>[], departures = <Duration>[];
    var totalBreak = Duration.zero;
    for (var i = 0; i < places.length; i++) {
      final arrival = arrivalOffsets[i] + totalBreak;
      arrivals.add(arrival);
      // Starting time means departure. The day ends on reaching the destination.
      final minutes = i > 0 && i < places.length - 1
          ? breakMinutes[places[i].id] ?? 0
          : 0;
      if (minutes < 0 || minutes > 1440) {
        throw ArgumentError('Breaks must be between 0 and 1440 minutes.');
      }
      final pause = Duration(minutes: minutes);
      departures.add(arrival + pause);
      totalBreak += pause;
    }
    return DayTimetable(
      List.unmodifiable(arrivals),
      List.unmodifiable(departures),
      totalBreak,
      walkingTime + totalBreak,
    );
  }
}

class DayTimetable {
  final List<Duration> arrivals, departures;
  final Duration totalBreak, totalDuration;
  const DayTimetable(
    this.arrivals,
    this.departures,
    this.totalBreak,
    this.totalDuration,
  );
}

/// Only verified, forward paths are offered. The guide database is read-only.
class WalkingDayPlanner {
  final Map<int, Location> locations;
  final Map<int, DayLeg> legs;
  final List<Location>? _walkingOrder;
  const WalkingDayPlanner(this.locations, this.legs, [this._walkingOrder]);
  List<Location> get orderedLocations =>
      _walkingOrder ??
      orderWalkingLocations(
        locations.values,
        legs.values.map((leg) => leg.path),
      );

  static Future<WalkingDayPlanner> load(CaminoRepository repository) async {
    final locations = <int, Location>{};
    final legs = <int, DayLeg>{};
    final allPaths = <Path>[];
    for (final stage in await repository.stages()) {
      final route = await repository.route(stage);
      allPaths.addAll(route.paths);
      for (final place in route.locations) {
        locations[place.id] = place;
      }
      if (!route.canGuide) continue;
      for (final path in route.paths) {
        final points = route.points.where((p) => p.pathId == path.id).toList();
        if (points.length < 2 ||
            points.any(
              (p) =>
                  p.elevation == null ||
                  !p.elevation!.isFinite ||
                  p.distance3dMeters == null ||
                  !p.distance3dMeters!.isFinite ||
                  p.distance3dMeters! < 0 ||
                  p.weightedDistance == null ||
                  !p.weightedDistance!.isFinite ||
                  p.weightedDistance! < 0,
            )) {
          continue;
        }
        legs[path.id] = DayLeg(path, points);
      }
    }
    return WalkingDayPlanner(
      locations,
      legs,
      orderWalkingLocations(locations.values, allPaths),
    );
  }

  List<List<int>> routes(int start, int finish) {
    if (start == finish) return [];
    final results = <List<int>>[];
    final outgoing = <int, List<DayLeg>>{};
    for (final leg in legs.values) {
      outgoing.putIfAbsent(leg.path.originLocationId, () => []).add(leg);
    }
    var explored = 0;
    void visit(int current, List<int> chain, Set<int> visited) {
      if (++explored > 10000) {
        throw StateError(
          'Choose a shorter walking day to narrow the route choices.',
        );
      }
      if (current == finish) {
        results.add(List.of(chain));
        if (results.length > 64) {
          throw StateError(
            'Too many route alternatives. Choose a shorter walking day.',
          );
        }
        return;
      }
      for (final leg in outgoing[current] ?? <DayLeg>[]) {
        final next = leg.path.destinationLocationId;
        if (visited.contains(next)) continue;
        if (chain.isNotEmpty) {
          final previous = legs[chain.last]!;
          if (const Distance(roundResult: false)(
                previous.points.last.position,
                leg.points.first.position,
              ) >
              150) {
            continue;
          }
          if (previous.path.stageId == leg.path.stageId &&
              leg.points.first.previousTrackPointId !=
                  previous.points.last.id) {
            continue;
          }
        }
        visit(next, [...chain, leg.path.id], {...visited, next});
      }
    }

    visit(start, [], {start});
    return results;
  }

  WalkingDay calculate(List<int> pathIds, double pace) {
    if (pathIds.isEmpty ||
        pathIds.toSet().length != pathIds.length ||
        !pace.isFinite ||
        pace < 1 ||
        pace > 8.5) {
      throw StateError('Choose a valid route and walking pace.');
    }
    final selected = pathIds
        .map(
          (id) =>
              legs[id] ??
              (throw StateError(
                'This saved route is unavailable in the current guide.',
              )),
        )
        .toList();
    final places = <Location>[];
    final arrivalOffsets = <Duration>[Duration.zero];
    final sections = <ElevationSection>[];
    double metres = 0, weighted = 0, ascent = 0, descent = 0, joins = 0;
    TrackPoint? previous;
    const distance = Distance(roundResult: false);
    for (var n = 0; n < selected.length; n++) {
      final leg = selected[n];
      if (n > 0 &&
          selected[n - 1].path.destinationLocationId !=
              leg.path.originLocationId) {
        throw StateError('The selected paths no longer connect.');
      }
      places.add(locations[leg.path.originLocationId]!);
      final samples = <ElevationPoint>[];
      final offset = metres;
      if (previous != null) {
        final gap = distance(previous.position, leg.points.first.position);
        if (gap > 150) {
          throw StateError(
            'There is a gap between these routes. Choose another route.',
          );
        }
        if (leg.path.stageId != selected[n - 1].path.stageId ||
            leg.points.first.previousTrackPointId != previous.id) {
          joins += gap;
          previous = null; // Never invent a slope or weight across stage joins.
        } else {
          samples.add(
            ElevationPoint(
              leg.path.id,
              0,
              0,
              previous.elevation!,
              previous.position,
            ),
          );
        }
      }
      for (final point in leg.points) {
        if (previous != null) {
          if (point.previousTrackPointId != previous.id) {
            throw StateError('Track connection is incomplete.');
          }
          metres += point.distance3dMeters!;
          weighted += point.weightedDistance!;
          final rise = point.elevation! - previous.elevation!;
          if (rise > 0) {
            ascent += rise;
          } else {
            descent -= rise;
          }
        }
        samples.add(
          ElevationPoint(
            leg.path.id,
            samples.length,
            metres - offset,
            point.elevation!,
            point.position,
          ),
        );
        previous = point;
      }
      sections.add(ElevationSection(leg.path, samples, offset));
      arrivalOffsets.add(WalkingTime.estimate(weighted, pace)!);
    }
    places.add(locations[selected.last.path.destinationLocationId]!);
    final stage = Stage.fromRow({
      'ID': -1,
      'stageName': '${places.first.name} to ${places.last.name}',
      'stageStartLocationID': places.first.id,
      'stageFinishLocationID': places.last.id,
    });
    return WalkingDay(
      selected,
      places,
      metres,
      ascent,
      descent,
      joins,
      WalkingTime.estimate(weighted, pace)!,
      ElevationProfile(stage, sections, [], [], locations: places),
      List.unmodifiable(arrivalOffsets),
    );
  }
}

/// Itinerary clock time, independent of the device's timezone.
/// Arrival estimates round up once, from cumulative walking time.
String walkingDayClock(int departureMinutes, Duration elapsed) {
  final total =
      departureMinutes +
      (elapsed.inMicroseconds / Duration.microsecondsPerMinute).ceil();
  final days = total ~/ (24 * 60);
  final hours = (total % (24 * 60)) ~/ 60;
  final minutes = total % 60;
  final clock =
      '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  return days == 0 ? clock : '$clock (+$days ${days == 1 ? 'day' : 'days'})';
}
