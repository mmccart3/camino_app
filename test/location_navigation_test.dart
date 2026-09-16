import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter/material.dart' hide Path;
import 'package:camino_app/ui/location_navigation.dart';
import 'package:camino_app/ui/stage_map_coverage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/services/location_route.dart';
import 'package:camino_app/services/offline_coverage.dart';
import 'package:camino_app/services/route_guidance.dart';

TrackPoint point(
  int id,
  double lon, {
  int path = 1,
  int? previous,
  double metres = 80,
  double weighted = 460,
}) => TrackPoint.fromRow({
  'track_point_id': id,
  'pathID': path,
  'latitude': 43.0,
  'longitude': lon,
  'previous_track_point_id': previous,
  'distance_3d_meters': metres,
  'weighted_distance': weighted,
});
Location location(int id, double lon) => Location.fromRow({
  'ID': id,
  'locationName': 'Place $id',
  'latitude': 43.0,
  'longitude': lon,
});
StageRoute route(
  int id,
  int origin,
  int destination,
  List<TrackPoint> points,
) => StageRoute(
  stage: Stage.fromRow({
    'ID': id,
    'stageName': 'Stage $id',
    'stageStartLocationID': origin,
    'stageFinishLocationID': destination,
  }),
  paths: [
    Path.fromRow({
      'pathID': id,
      'stageID': id,
      'originLoc': origin,
      'destinationLoc': destination,
    }),
  ],
  locations: [],
  segments: [points],
  points: points,
  issues: [],
  locationsOrdered: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final covered in [true, false]) {
    testWidgets('stage map Google fallback when coverage is $covered', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StageMapCoverage(
              route: route(1, 1, 2, [
                point(1, -1.5),
                point(2, -1.499, previous: 1),
              ]),
              coverageCheck: (_) async => covered,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Join this stage with Google Maps'),
        covered ? findsNothing : findsOneWidget,
      );
      expect(
        find.textContaining('outside your downloaded map area'),
        covered ? findsNothing : findsOneWidget,
      );
      expect(find.text('Online basemap'), findsNothing);
    });
  }
  testWidgets(
    'uncovered destination explains fallback without requesting GPS',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationNavigationButton(
              repository: CaminoRepository(
                LocalDatabase(factory: databaseFactoryFfi),
              ),
              location: location(2, -1.498),
              coverageCheck: (_) async => false,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Navigate here offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('This location is outside your downloaded map area.'),
        findsOneWidget,
      );
      expect(find.text('Navigate with Google Maps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('forward and reverse incoming metrics end at selected location', () {
    final points = [
      point(1, -1.5),
      point(2, -1.499, previous: 1, metres: 90, weighted: 460),
      point(3, -1.498, previous: 2, metres: 110, weighted: 920),
    ];
    final forward = LocationRoutePlanner.plan(
      [route(1, 1, 2, points)],
      location(2, -1.498),
      points.first.position,
    )!;
    final a = RouteGuidanceService().calculate(
      forward.points,
      points.first.position,
      4.6,
    )!;
    expect(a.remainingMeters, 200);
    expect(a.timeRemaining!.inSeconds, 300);
    final reverse = LocationRoutePlanner.plan(
      [route(1, 1, 2, points)],
      location(1, -1.5),
      points.last.position,
    )!;
    final b = RouteGuidanceService().calculate(
      reverse.points,
      points.last.position,
      4.6,
    )!;
    expect(reverse.reversed, isTrue);
    expect(b.remainingMeters, 200);
    expect(b.timeRemaining!.inSeconds, 300);
  });
  test(
    'cross-stage paths join only on compatible location and predecessor',
    () {
      final a = [point(1, -1.5), point(2, -1.499, previous: 1)];
      final b = [
        point(3, -1.499, path: 2, previous: 2),
        point(4, -1.498, path: 2, previous: 3),
      ];
      final good = [route(1, 1, 2, a), route(2, 2, 3, b)];
      expect(
        LocationRoutePlanner.plan(
          good,
          location(3, -1.498),
          a.first.position,
        )!.points.length,
        4,
      );
      expect(
        LocationRoutePlanner.plan(
          [route(1, 1, 2, a), route(2, 4, 3, b)],
          location(3, -1.498),
          a.first.position,
        ),
        isNull,
      );
    },
  );
  test(
    'rejects missing destination connection, large gaps and distant user',
    () {
      final a = [point(1, -1.5), point(2, -1.499, previous: 1)];
      expect(
        LocationRoutePlanner.plan(
          [route(1, 1, 2, a)],
          location(3, -1.499),
          a.first.position,
        ),
        isNull,
      );
      expect(
        LocationRoutePlanner.plan(
          [route(1, 1, 2, a)],
          location(2, -1.499),
          const LatLng(44, -1.5),
        ),
        isNull,
      );
      expect(
        LocationRoutePlanner.plan(
          [
            route(1, 1, 2, [a.first, point(2, -1.4, previous: 1)]),
          ],
          location(2, -1.4),
          a.first.position,
        ),
        isNull,
      );
    },
  );
  test('real database destination route and bundled coverage', () async {
    sqfliteFfiInit();
    final folder = await Directory.systemTemp.createTemp('location_route_');
    final local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    try {
      final repository = CaminoRepository(local);
      final stage = (await repository.stages()).firstWhere((s) => s.id == 1);
      final data = await repository.route(stage);
      final destination = data.locations.firstWhere(
        (l) => l.id == stage.finishLocationId,
      );
      final planned = LocationRoutePlanner.plan(
        [data],
        destination,
        data.points.first.position,
      );
      expect(planned, isNotNull);
      final map = File('assets/offline_maps/stages1_6.mbtiles').absolute.path;
      expect(
        await OfflineCoverage.covers(
          planned!.points.map((p) => p.position).toList(),
          path: map,
        ),
        isTrue,
      );
      expect(
        await OfflineCoverage.covers([const LatLng(51.5, -0.1)], path: map),
        isFalse,
      );
    } finally {
      await (await local.database).close();
      await folder.delete(recursive: true);
    }
  });
  test(
    'coverage rejects a missing intermediate tile even when endpoints exist',
    () async {
      sqfliteFfiInit();
      final folder = await Directory.systemTemp.createTemp('coverage_gap_');
      final path = '${folder.path}/gap.mbtiles';
      final db = await databaseFactoryFfi.openDatabase(path);
      try {
        await db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
        await db.execute(
          "INSERT INTO metadata VALUES ('format','pbf'),('minzoom','14'),('maxzoom','14')",
        );
        await db.execute(
          'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)',
        );
        await db.execute(
          "INSERT INTO tiles VALUES (14,8192,8191,X'01'), (14,8194,8191,X'01')",
        );
        await db.close();
        const a = LatLng(-0.010986, 0.010986), b = LatLng(-0.010986, 0.054931);
        expect(await OfflineCoverage.covers([a], path: path), isTrue);
        expect(await OfflineCoverage.covers([b], path: path), isTrue);
        expect(await OfflineCoverage.covers([a, b], path: path), isFalse);
      } finally {
        if (db.isOpen) await db.close();
        // Provider closes its FFI reader asynchronously.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await folder.delete(recursive: true);
      }
    },
  );
}
