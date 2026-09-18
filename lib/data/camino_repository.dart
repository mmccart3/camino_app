import 'local_database.dart';
import 'models.dart';
import 'schema.dart';
import 'route_assembler.dart';
import 'stage_order.dart';

class CaminoRepository {
  final LocalDatabase local;
  CaminoRepository(this.local);
  Future<Map<int, Location>> locationsByIds(Set<int> ids) async {
    if (ids.isEmpty) return {};
    final db = await local.database;
    final rows = await db.query(
      'locations',
      where: 'ID IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids.toList(),
    );
    return {for (final row in rows) integer(row, 'ID'): Location.fromRow(row)};
  }

  Future<List<Row>> _rows(
    String table, {
    String? where,
    List<Object?>? args,
    String order = 'ID',
  }) async => (await local.database).query(
    '"$table"',
    where: where,
    whereArgs: args,
    orderBy: order,
  );

  Future<List<Stage>> stages() async =>
      orderStages((await _rows(CaminoSchema.stages)).map(Stage.fromRow));
  Future<Stage?> stage(int id) async {
    final rows = await _rows(CaminoSchema.stages, where: 'ID = ?', args: [id]);
    return rows.isEmpty ? null : Stage.fromRow(rows.single);
  }

  Future<List<MapHotspot>> mapHotspots(int stageId) async {
    final db = await local.database;
    final rows = await db.rawQuery(
      '''SELECT l.*, m.ID AS hotspotId,
      m.TLX1920, m.TLY1920, m.BRX1920, m.BRY1920
      FROM mapLocationCoords m JOIN locations l ON l.ID = m.locationId
      WHERE m.stageId = ? ORDER BY m.ID''',
      [stageId],
    );
    return rows.map(MapHotspot.fromRow).where((h) => h.isValid).toList();
  }

  Future<List<Location>> locations(int stageId) async {
    final db = await local.database;
    return (await db.rawQuery(
      '''
      SELECT l.* FROM locations l WHERE l.ID IN (
        SELECT originLoc FROM paths WHERE stageID = ?
        UNION SELECT destinationLoc FROM paths WHERE stageID = ?
        UNION SELECT stageStartLocationID FROM stages WHERE ID = ?
        UNION SELECT stageFinishLocationID FROM stages WHERE ID = ?
      ) ORDER BY l.ID
    ''',
      [stageId, stageId, stageId, stageId],
    )).map(Location.fromRow).toList();
  }

  /// Paragraphs belong to locations in the actual database, not stages.
  /// ID provides deterministic display order because no paragraph order exists.
  Future<List<Paragraph>> paragraphs(int locationId) async => (await _rows(
    CaminoSchema.paragraphs,
    where: 'locationID = ?',
    args: [locationId],
  )).map(Paragraph.fromRow).toList();
  Future<List<Albergue>> albergues(int locationId) async => (await _rows(
    CaminoSchema.albergues,
    where: 'locationID = ?',
    args: [locationId],
  )).map(Albergue.fromRow).toList();
  Future<List<PrivateAccommodation>> privateAccommodation(
    int locationId,
  ) async => (await _rows(
    CaminoSchema.privateAccommodation,
    where: 'locationID = ?',
    args: [locationId],
  )).map(PrivateAccommodation.fromRow).toList();
  Future<List<Path>> paths(int stageId) async => (await _rows(
    CaminoSchema.paths,
    where: 'stageID = ?',
    args: [stageId],
    order: 'pathID',
  )).map(Path.fromRow).toList();
  Future<List<TrackPoint>> trackPoints(int pathId) async =>
      RouteAssembler.orderPoints(
        (await _rows(
          CaminoSchema.trackPoints,
          where: 'pathID = ?',
          args: [pathId],
          order: 'track_point_id',
        )).map(TrackPoint.fromRow).toList(),
      );

  Future<StageRoute> route(Stage stage) async {
    final pathRows = await paths(stage.id);
    final locationRows = await locations(stage.id);
    final db = await local.database;
    // One query for a whole stage rather than one query per point/path.
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM track_points t JOIN paths p ON p.pathID = t.pathID
      WHERE p.stageID = ? ORDER BY t.track_point_id
    ''',
      [stage.id],
    );
    final groups = <int, List<Row>>{};
    for (final row in rows) {
      groups.putIfAbsent(integer(row, 'pathID'), () => []).add(row);
    }
    final tracks = <int, List<TrackPoint>>{}, issues = <String>[];
    for (final entry in groups.entries) {
      try {
        tracks[entry.key] = RouteAssembler.orderPoints(
          entry.value.map(TrackPoint.fromRow).toList(),
        );
      } on RouteDataException catch (error) {
        issues.add('Path ${entry.key}: ${error.message}');
      } on FormatException catch (error) {
        issues.add('Path ${entry.key}: ${error.message}');
      }
    }
    return RouteAssembler.assemble(
      stage,
      pathRows,
      locationRows,
      tracks,
      trackIssues: issues,
    );
  }
}
