import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/services/route_guidance.dart';
import 'package:camino_app/services/safe_links.dart';
import 'package:camino_app/services/settings_service.dart';
import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late CaminoRepository repository;
  var loads = 0;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('camino_real_test_');
    loads = 0;
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: temporary.path,
      loadAsset: () async {
        loads++;
        return File('assets/database/camino.sqlite').readAsBytes();
      },
    );
    repository = CaminoRepository(local);
  });
  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test(
    'map hotspots use stage links, 1920 coordinates and location rows',
    () async {
      final items = await repository.mapHotspots(2);
      expect(items.first.id, 1);
      expect(items.first.location.id, 9);
      expect(items.first.left, 1453);
      expect(items.first.top, 5);
      expect(items.first.right, 1741);
      expect(items.first.bottom, 109);
      expect(
        (await repository.mapHotspots(30)).any((h) => h.id == 181),
        isFalse,
      );
      expect(await repository.mapHotspots(-1), isEmpty);
    },
  );
  test(
    'copies real asset once, shares opening and reuses across launches',
    () async {
      final handles = await Future.wait([local.database, local.database]);
      expect(identical(handles.first, handles.last), isTrue);
      expect(loads, 1);
      await local.close();
      await local.database;
      expect(loads, 2); // Re-read asset fingerprint; reuse the existing copy.
      expect(
        await File((await local.database).path).readAsBytes(),
        await File('assets/database/camino.sqlite').readAsBytes(),
      );
      final db = await local.database;
      await expectLater(
        db.execute("UPDATE stages SET stageName = 'changed' WHERE ID = 1"),
        throwsA(anything),
      );
    },
  );
  test(
    'reads seven real concepts, nullable columns and exact affiliate text',
    () async {
      expect((await repository.stages()).map((stage) => stage.id), [
        1,
        43,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        38,
        37,
        39,
        44,
        40,
        41,
        42,
      ]);
      final stage = (await repository.stage(1))!;
      expect(stage.startLocationId, 1);
      expect(stage.finishLocationId, 9);
      expect((await repository.locations(1)).map((l) => l.id), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
      expect((await repository.paragraphs(1)).first.locationId, 1);
      expect(
        (await repository.albergues(1)).first.name,
        'Ospitalia Refuge Municipal',
      );
      expect((await repository.albergues(1)).first.source['numberOfBeds'], 32);
      final private = (await repository.privateAccommodation(1)).first;
      expect(
        private.bookingUrl,
        'https://www.booking.com/hotel/fr/maison-e-bernat.html',
      );
      expect(private.imageUrls, isEmpty);
      expect((await repository.paths(1)).length, 8);
      expect((await repository.trackPoints(2)).first.previousTrackPointId, 148);
      expect(await repository.stage(999), isNull);
      expect(await repository.locations(999), isEmpty);
    },
  );
  test(
    'preserves every stored booking URL including sentinels and affiliate IDs',
    () async {
      final db = await local.database;
      for (final table in ['albergues', 'privateAccommDetail']) {
        final rows = await db.query(table);
        for (final row in rows) {
          final Accommodation place = table == 'albergues'
              ? Albergue.fromRow(row)
              : PrivateAccommodation.fromRow(row);
          expect(
            place.bookingUrl,
            row[table == 'albergues'
                ? 'albergueBookingDotComURL'
                : 'privateAccommBookingDotComURL'],
          );
        }
      }
    },
  );
  test(
    'orders whole stage 1 across eight paths and all 778 linked points',
    () async {
      final route = await repository.route((await repository.stage(1))!);
      expect(route.issues, isEmpty, reason: route.issues.join('; '));
      expect(route.canGuide, isTrue);
      expect(route.paths.map((p) => p.id), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(route.points.length, 778);
      expect(route.points.first.id, 1);
      expect(route.points.last.id, 778);
      expect(route.points.last.waypointName, 'Roncesvalles');
      final guidance = RouteGuidanceService().calculate(
        route.points,
        route.points[147].position,
        4.5,
      )!;
      expect(guidance.nextWaypoint?.id, 240);
      expect(guidance.remainingMeters, greaterThan(15000));
      final db = await local.database;
      final totals = (await db.rawQuery(
        '''SELECT SUM(distance_3d_meters) AS metres,
        SUM(weighted_distance) AS weighted FROM track_points
        WHERE track_point_id > 148 AND track_point_id <= 240''',
      )).single;
      expect(
        guidance.distanceToNextMeters,
        closeTo((totals['metres'] as num).toDouble(), 0.001),
      );
      expect(
        guidance.timeToNext!.inMicroseconds,
        closeTo((totals['weighted'] as num).toDouble() / 4.5 * 1000000, 1),
      );
    },
  );
  test(
    'stage 2 assembles Roncesvalles to Zubiri from new track points',
    () async {
      final route = await repository.route((await repository.stage(2))!);
      expect(route.issues, isEmpty);
      expect(route.canGuide, isTrue);
      expect(route.paths.map((p) => p.id), [9, 10, 11, 12, 13, 14]);
      expect(route.points.length, 1270);
      expect(route.points.last.waypointName, 'Zubiri');
      final result = RouteGuidanceService().calculate(
        route.points,
        route.points.first.position,
        4,
      );
      expect(result!.remainingMeters, greaterThan(15000));
      expect(result.remainingMeters, lessThan(30000));
    },
  );
  test(
    'stage 5 subdivides both gaps under 50 metres without changing totals',
    () async {
      final route = await repository.route((await repository.stage(5))!);
      expect(route.points.length, 419);
      expect(route.paths.map((p) => p.id), [33, 34, 35, 36, 37]);
      expect(route.issues, [
        'Track geometry does not reach both declared stage endpoints.',
      ]);
      expect(
        route.points[route.points.indexWhere((p) => p.id == 5192) + 1].id,
        5409,
      );
      expect(
        route.points[route.points.indexWhere((p) => p.id == 5282) + 1].id,
        5413,
      );
      expect(
        route.points.fold<double>(0, (sum, p) => sum + p.distance3dMeters!),
        closeTo(21617.677137568193, 0.000001),
      );
      expect(
        route.points.fold<double>(0, (sum, p) => sum + p.weightedDistance!),
        closeTo(65669.50279943996, 0.000001),
      );
      expect(route.points.last.id, 5406);
      expect(route.points.last.pathId, 37);
      expect(route.canGuide, isFalse);
      expect(
        route.issues,
        contains(
          'Track geometry does not reach both declared stage endpoints.',
        ),
      );
    },
  );
  test('stage 4 imports all tracks and flags the endpoint mismatch', () async {
    final route = await repository.route((await repository.stage(4))!);
    expect(route.points.length, 870);
    expect(route.paths.length, 7);
    expect(route.segments.length, 7);
    expect(route.issues, [
      'Track geometry does not reach both declared stage endpoints.',
    ]);
    expect(route.canGuide, isFalse);
  });
  test(
    'missing tracks and invalid stage graphs do not become invented routes',
    () async {
      final noTracks = await repository.route((await repository.stage(6))!);
      expect(noTracks.canGuide, isFalse);
      expect(noTracks.points, isEmpty);
      expect(noTracks.locations, isNotEmpty);
      for (final id in [24, 25]) {
        final invalid = await repository.route((await repository.stage(id))!);
        expect(invalid.locationsOrdered, isFalse);
        expect(invalid.canGuide, isFalse);
        expect(invalid.locations, isNotEmpty);
        expect(invalid.issues, isNotEmpty);
      }
    },
  );
  test(
    'every stage can be browsed despite partially populated route data',
    () async {
      for (final stage in await repository.stages()) {
        final route = await repository.route(stage);
        expect(route.locations, isNotEmpty, reason: 'Stage ${stage.id}');
        if (stage.id != 1 && stage.id != 2 && stage.id != 3) {
          expect(route.canGuide, isFalse);
        }
      }
    },
  );
  test(
    'stage 3 corrected assignments enable complete weighted guidance',
    () async {
      final route = await repository.route((await repository.stage(3))!);

      expect(route.issues, isEmpty, reason: route.issues.join('; '));
      expect(route.canGuide, isTrue);
      expect(route.points.length, 722);
      final guidance = RouteGuidanceService().calculate(
        route.points,
        route.points.first.position,
        4.6,
      )!;
      expect(guidance.remainingMeters, closeTo(21015.834273, 0.001));
      expect(guidance.timeRemaining!.inSeconds, closeTo(64048.535324 / 4.6, 1));
      expect(guidance.nextWaypoint, isNotNull);
      expect(route.segments.length, 11);
      expect(route.paths.map((p) => p.id), List.generate(11, (i) => i + 15));
      expect(
        route.points.fold<double>(
          0,
          (sum, point) => sum + point.distance3dMeters!,
        ),
        closeTo(21015.834273, 0.001),
      );
      expect(route.points[1].source['distance_3d_meters'], isNull);
      expect(route.points[1].distance3dMeters, closeTo(91.848781, 0.001));
    },
  );
  test('corrupt asset is never promoted and retry works', () async {
    var corrupt = true;
    final broken = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: '${temporary.path}/broken',
      loadAsset: () async => corrupt
          ? Uint8List.fromList([1, 2, 3])
          : File('assets/database/camino.sqlite').readAsBytes(),
    );
    await expectLater(broken.database, throwsA(anything));
    expect(
      await File(
        '${temporary.path}/broken/camino-${sha256.convert([1, 2, 3])}.sqlite',
      ).exists(),
      isFalse,
    );
    corrupt = false;
    await broken.database;
    await broken.close();
  });
  test(
    'old fixture remains untouched and new schema uses a separate installed file',
    () async {
      final old = File('${temporary.path}/camino-v1.sqlite');
      await old.writeAsString('legacy fixture');
      await local.database;
      expect(await old.readAsString(), 'legacy fixture');
      expect(await File((await local.database).path).exists(), isTrue);
    },
  );
  test('schema validation rejects missing tables and duplicate IDs', () async {
    final file = '${temporary.path}/invalid.sqlite';
    await File(
      file,
    ).writeAsBytes(await File('assets/database/camino.sqlite').readAsBytes());
    final db = await databaseFactoryFfi.openDatabase(file);
    await db.execute('INSERT INTO stages SELECT * FROM stages WHERE ID=1');
    await expectLater(LocalDatabase.validate(db), throwsStateError);
    await db.execute(
      'DELETE FROM stages WHERE rowid=(SELECT MAX(rowid) FROM stages)',
    );
    await db.execute('DROP TABLE track_points');
    await expectLater(LocalDatabase.validate(db), throwsStateError);
    await db.close();
  });
  test(
    'a changed bundled database selects a new copy without deleting the old one',
    () async {
      final originalBytes = await File(
        'assets/database/camino.sqlite',
      ).readAsBytes();
      var bundledBytes = originalBytes;
      final loader = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: temporary.path,
        loadAsset: () async => bundledBytes,
      );
      final first = await loader.database;
      final firstPath = first.path;
      await loader.close();
      final edited = File('${temporary.path}/edited.sqlite');
      await edited.writeAsBytes(originalBytes);
      final editor = await databaseFactoryFfi.openDatabase(edited.path);
      await editor.update(
        'stages',
        {'stageName': 'Updated stage name'},
        where: 'ID = ?',
        whereArgs: [1],
      );
      await editor.close();
      bundledBytes = await edited.readAsBytes();
      final updated = await loader.database;
      expect(updated.path, isNot(firstPath));
      expect(
        (await updated.query(
          'stages',
          where: 'ID = ?',
          whereArgs: [1],
        )).single['stageName'],
        'Updated stage name',
      );
      expect(await File(firstPath).readAsBytes(), originalBytes);
      await loader.close();
      expect((await loader.database).path, updated.path);
      await loader.close();
    },
  );
  test('off-route threshold persists and rejects invalid values', () async {
    final memory = MemoryPreferences();
    final settings = SettingsService(preferences: memory);
    expect(settings.offRouteMetres, 50);
    await settings.setOffRouteMetres(120);
    final restored = SettingsService(preferences: memory);
    await restored.load();
    expect(restored.offRouteMetres, 120);
    for (final value in [0.0, 501.0, double.nan]) {
      await expectLater(settings.setOffRouteMetres(value), throwsArgumentError);
    }
    memory.values['off_route_metres'] = double.infinity;
    final fallback = SettingsService(preferences: memory);
    await fallback.load();
    expect(fallback.offRouteMetres, 50);
  });
  test('walking pace reloads and invalid values are rejected', () async {
    final memory = MemoryPreferences();
    final settings = SettingsService(preferences: memory);
    await settings.setPace(5.2);
    final reloaded = SettingsService(preferences: memory);
    await reloaded.load();
    expect(reloaded.paceKmh, 5.2);
    await expectLater(reloaded.setPace(0), throwsArgumentError);
    memory.values['walking_pace_kmh'] = double.nan;
    final fallback = SettingsService(preferences: memory);
    await fallback.load();
    expect(fallback.paceKmh, 4.6);
    for (final value in [1.0, 8.5]) {
      await settings.setPace(value);
      await reloaded.load();
      expect(reloaded.paceKmh, value);
    }
    for (final value in [0.9, 8.6, double.infinity]) {
      await expectLater(settings.setPace(value), throwsArgumentError);
    }
  });
  test(
    'Windows selects its SQLite factory without manual injection',
    () async {
      final windowsLocal = LocalDatabase(
        directory: '${temporary.path}/windows',
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      try {
        expect((await CaminoRepository(windowsLocal).stages()).length, 41);
      } finally {
        await windowsLocal.close();
      }
    },
    skip: !Platform.isWindows,
  );
  test('URL validation excludes sentinel values and unsafe schemes', () {
    for (final value in [
      'not on Booking',
      'no website available',
      'NULL',
      'javascript:alert(1)',
      'file:///x',
      'https://user:password@example.com',
    ]) {
      expect(SafeLinks.isSafe(value), isFalse);
    }
    expect(
      SafeLinks.isSafe('https://www.booking.com/?aid=1627093&label=a%2Fb'),
      isTrue,
    );
  });

  group('graph and geometry edge cases', () {
    TrackPoint point(
      int id,
      int? previous,
      double lat,
      double lon, {
      bool waypoint = false,
      int pathId = 1,
      double? metres = 100,
      double? weighted = 360,
    }) => TrackPoint.fromRow({
      'track_point_id': id,
      'pathID': pathId,
      'previous_track_point_id': previous,
      'latitude': lat,
      'longitude': lon,
      'waypoint': waypoint ? 1 : 0,
      'distance_3d_meters': metres,
      'weighted_distance': weighted,
    });
    final service = RouteGuidanceService();
    test('predecessor order wins over IDs and insertion order', () {
      final points = [
        point(3, 20, 0, 0.02),
        point(20, 10, 0, 0.01),
        point(10, 0, 0, 0),
      ];
      expect(RouteAssembler.orderPoints(points).map((p) => p.id), [10, 20, 3]);
    });
    test('broken links, forks and cycles fail explicitly', () {
      for (final rows in [
        [point(1, 2, 0, 0), point(2, 1, 0, 0.01)],
        [point(1, 0, 0, 0), point(2, 99, 0, 0.01)],
        [point(1, 0, 0, 0), point(2, 1, 0, 0.01), point(3, 1, 0, 0.02)],
      ]) {
        expect(
          () => RouteAssembler.orderPoints(rows),
          throwsA(isA<RouteDataException>()),
        );
      }
    });
    test(
      'nearest stored point uses incoming 3D and weighted segments ahead',
      () {
        final points = [
          point(1, 0, 0, 0, metres: 9999, weighted: 9999),
          point(2, 1, 0, 0.01, metres: 100, weighted: 460),
          point(3, 2, 0.01, 0.01, waypoint: true, metres: 200, weighted: 920),
          point(4, 3, 0.02, 0.01, metres: 300, weighted: 1380),
        ];
        final result = service.calculate(points, const LatLng(0, 0.009), 4.6)!;
        expect(result.nearestTrackPoint.id, 2);
        expect(result.nearestPosition.longitude, 0.01);
        expect(result.offRouteMeters, closeTo(111.3, 1));
        expect(result.nextWaypoint?.id, 3);
        expect(result.distanceToNextMeters, 200);
        expect(result.remainingMeters, 500);
        expect(result.timeToNext, const Duration(seconds: 200));
        expect(result.timeRemaining, const Duration(seconds: 500));
        final faster = service.calculate(points, points[1].position, 8)!;
        expect(
          faster.timeRemaining!.inMicroseconds,
          closeTo(2300 / 8 * 1000000, 1),
        );
        final atWaypoint = service.calculate(points, points[2].position, 4.6)!;
        expect(atWaypoint.nextWaypoint?.id, 4);
        expect(atWaypoint.distanceToNextMeters, 300);
        final end = service.calculate(points, points.last.position, 4.6)!;
        expect(end.remainingMeters, 0);
        expect(end.timeRemaining, Duration.zero);
        expect(end.nextWaypoint, isNull);
      },
    );
    test('missing metrics are unavailable independently and only ahead', () {
      final points = [
        point(1, 0, 0, 0, metres: null, weighted: null),
        point(2, 1, 0, 0.01, waypoint: true),
        point(3, 2, 0, 0.02, metres: null, weighted: -1),
      ];
      final result = service.calculate(points, points.first.position, 4.6)!;
      expect(result.distanceToNextMeters, 100);
      expect(result.timeToNext, isNotNull);
      expect(result.remainingMeters, isNull);
      expect(result.timeRemaining, isNull);
      final partial = service.calculate(
        [points.first, point(2, 1, 0, 0.01, weighted: double.nan)],
        points.first.position,
        4.6,
      )!;
      expect(partial.remainingMeters, 100);
      expect(partial.timeRemaining, isNull);
    });
    test(
      'empty, duplicate coordinates, singleton and invalid pace are handled',
      () {
        expect(service.calculate([], const LatLng(0, 0), 4), isNull);
        final a = point(1, 0, 0, 0);
        expect(service.calculate([a], a.position, 4)!.remainingMeters, 0);
        expect(
          service
              .calculate([a, a, point(2, 1, 0, 0.01)], a.position, 4)!
              .remainingMeters!
              .isFinite,
          isTrue,
        );
        expect(
          () => service.calculate([a], a.position, 0),
          throwsArgumentError,
        );
        expect(
          () => service.calculate([a], a.position, double.nan),
          throwsArgumentError,
        );
      },
    );
  });
}
