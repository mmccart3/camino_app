import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'camino_repository.dart';
import 'models.dart';
import 'route_assembler.dart';
import 'elevation_profile.dart';

class ElevationRepository {
  final CaminoRepository guide;
  ElevationRepository(this.guide);

  Future<List<ElevationProfile>> all() async {
    final stages = await guide.stages();
    final result = <ElevationProfile>[];
    for (final stage in stages) {
      result.add(await profile(stage));
    }
    return result;
  }

  Future<ElevationProfile> profile(Stage stage) async {
    final db = await guide.local.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='elevation_points'",
    );
    final paths = await guide.paths(stage.id);
    List<Path> ordered;
    try {
      ordered = RouteAssembler.orderPaths(stage, paths);
    } on RouteDataException catch (error) {
      return ElevationProfile(stage, [], paths.map((p) => p.id).toList(), [
        error.message,
      ]);
    }
    final rows = tables.isEmpty
        ? <Row>[]
        : await db.rawQuery(
            '''
      SELECT e.* FROM elevation_points e JOIN paths p ON p.pathID=e.pathID
      WHERE p.stageID=? ORDER BY e.pathID,e.sequence''',
            [stage.id],
          );
    final groups = <int, List<ElevationPoint>>{};
    for (final row in rows) {
      final point = ElevationPoint.fromRow(row);
      groups.putIfAbsent(point.pathId, () => []).add(point);
    }
    final sections = <ElevationSection>[],
        missing = <int>[],
        issues = <String>[];
    double offset = 0;
    const distance = Distance();
    ElevationPoint? previous;
    for (final path in ordered) {
      final points = groups[path.id] ?? [];
      if (points.length < 2) {
        missing.add(path.id);
        previous = null;
        continue;
      }
      if (previous != null) {
        final gap = distance.as(
          LengthUnit.Meter,
          previous.position,
          points.first.position,
        );
        if (gap > 25) {
          issues.add(
            'Paths ${previous.pathId}–${path.id}: ${gap.round()} m between supplied sections.',
          );
        }
      }
      sections.add(ElevationSection(path, List.unmodifiable(points), offset));
      offset += points.last.distanceMetres;
      previous = points.last;
    }
    return ElevationProfile(stage, sections, missing, issues);
  }
}
