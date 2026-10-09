import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/services/offline_coverage.dart';
import 'package:camino_app/services/offline_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stage 6 replacement enables guidance and uses corrected WGS84 totals',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('stage6_import_');
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: directory.path,
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      try {
        final repository = CaminoRepository(local);
        final route = await repository.route((await repository.stage(6))!);
        expect(route.points.length, 896);
        expect(route.points.first.id, 12000);
        expect(route.points.last.id, 12895);
        expect(route.points.last.pathId, 43);
        for (var i = 1; i < route.points.length; i++) {
          expect(route.points[i].previousTrackPointId, route.points[i - 1].id);
          expect(route.points[i].elevation, greaterThan(400));
          expect(route.points[i].distance3dMeters, isNotNull);
          expect(route.points[i].weightedDistance, isNotNull);
        }
        expect(route.issues, isEmpty);
        expect(route.canGuide, isTrue);
        expect(
          await OfflineCoverage.covers([
            ...route.points.map((p) => p.position),
            route.locations.last.position!,
          ], path: File(OfflineMap.assetPath).absolute.path),
          isTrue,
        );
        expect(
          route.points.fold<double>(0, (sum, p) => sum + p.distance3dMeters!),
          closeTo(21606.655505908446, 0.000001),
        );
        expect(
          route.points.fold<double>(0, (sum, p) => sum + p.weightedDistance!) /
              4.6 /
              60,
          closeTo(337.0502373387067, 0.000001),
        );
      } finally {
        await local.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
