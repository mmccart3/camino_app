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
      expect((await repository.stages()).length, 41);
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
    'missing tracks and invalid stage graphs do not become invented routes',
    () async {
      final noTracks = await repository.route((await repository.stage(3))!);
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
        if (stage.id != 1 && stage.id != 2) {
          expect(route.canGuide, isFalse);
        }
      }
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
    expect(fallback.paceKmh, 4.5);
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
    }) => TrackPoint.fromRow({
      'track_point_id': id,
      'pathID': pathId,
      'previous_track_point_id': previous,
      'latitude': lat,
      'longitude': lon,
      'waypoint': waypoint ? 1 : 0,
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
    test('projection and along-route distance respect corners and pace', () {
      final points = [
        point(1, 0, 0, 0),
        point(2, 1, 0, 0.01, waypoint: true),
        point(3, 2, 0.01, 0.01, waypoint: true),
      ];
      final result = service.calculate(points, const LatLng(0, 0.005), 4)!;
      expect(result.nearestPosition.longitude, closeTo(0.005, 0.000001));
      expect(result.offRouteMeters, closeTo(0, 0.1));
      expect(result.nextWaypoint?.id, 2);
      expect(result.distanceToNextMeters, closeTo(556.6, 1));
      expect(result.remainingMeters, closeTo(1662.34, 1));
      expect(result.timeRemaining.inSeconds, closeTo(1496, 2));
      expect(
        service
            .calculate(points, const LatLng(0, 0.005), 8)!
            .timeRemaining
            .inSeconds,
        closeTo(result.timeRemaining.inSeconds / 2, 1),
      );
      final off = service.calculate(points, const LatLng(-0.001, 0.005), 4)!;
      expect(off.offRouteMeters, closeTo(110.6, 1));
      expect(off.distanceToNextMeters, closeTo(556.6, 1));
      final end = service.calculate(points, points.last.position, 4)!;
      expect(end.remainingMeters, closeTo(0, 0.1));
      expect(end.nextWaypoint, isNull);
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
              .remainingMeters
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
