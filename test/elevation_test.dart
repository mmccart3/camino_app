import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/elevation_repository.dart';
import 'package:camino_app/data/elevation_profile.dart';
import 'package:camino_app/ui/elevation_chart.dart';
import 'package:camino_app/ui/elevation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late CaminoRepository guide;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('camino_elevation_');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: temporary.path,
      loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
    );
    guide = CaminoRepository(local);
  });
  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test(
    'sample import is ordered per path and preserves navigation records',
    () async {
      final repository = ElevationRepository(guide);
      final stage1 = await repository.profile((await guide.stage(1))!);
      expect(stage1.sampleCount, 2455);
      final stage2 = await repository.profile((await guide.stage(2))!);
      expect(stage2.sampleCount, 2185);
      expect(stage2.missingPaths, isEmpty);
      final stage3 = await repository.profile((await guide.stage(3))!);
      expect(stage3.sampleCount, 2079);
      expect(stage3.missingPaths, isEmpty);
      expect(stage3.sections.length, 11);
      final stage4 = await repository.profile((await guide.stage(4))!);
      expect(stage4.sampleCount, 2495);
      expect(stage4.missingPaths, isEmpty);

      expect(stage2.sections.map((s) => s.points.length), [
        307,
        380,
        493,
        184,
        457,
        364,
      ]);

      expect(stage1.sections.length, 8);
      expect(stage1.sections.first.points.first.distanceMetres, 0);
      expect(stage1.sections.first.points.last.distanceMetres, 5300);
      expect(stage1.sections[1].points.first.sequence, 0);
      expect(stage1.sections[1].points.first.distanceMetres, 0);
      final stage5 = await repository.profile((await guide.stage(5))!);
      expect(stage5.sampleCount, 2162);
      expect(stage5.issues, isEmpty);
      final stage6 = await repository.profile((await guide.stage(6))!);
      expect(stage6.missingPaths, isEmpty);
      expect(stage6.sampleCount, 2155);
      final stage7 = await repository.profile((await guide.stage(7))!);
      expect(stage7.sampleCount, 2801);
      final stage8 = await repository.profile((await guide.stage(8))!);
      expect(stage8.sampleCount, 2859);
      final stage9 = await repository.profile((await guide.stage(11))!);
      expect(stage9.sampleCount, 2121);
      final stage10 = await repository.profile((await guide.stage(12))!);
      expect(stage10.sampleCount, 2245);
      final stage11 = await repository.profile((await guide.stage(13))!);
      expect(stage11.sampleCount, 2390);
      final stage12 = await repository.profile((await guide.stage(14))!);
      expect(stage12.sampleCount, 2647);
      final river = await repository.profile((await guide.stage(15))!);
      expect(river.sampleCount, 2643);
      final stage13 = await repository.profile((await guide.stage(16))!);
      expect(stage13.sampleCount, 2043);
      final stage14 = await repository.profile((await guide.stage(17))!);
      expect(stage14.sampleCount, 1998);
      final stage15 = await repository.profile((await guide.stage(18))!);
      expect(stage15.sampleCount, 2486);
      final road16 = await repository.profile((await guide.stage(19))!);
      expect(road16.sampleCount, 1884);
      final river16 = await repository.profile((await guide.stage(20))!);
      expect(river16.sampleCount, 2001);
      final stage17 = await repository.profile((await guide.stage(21))!);
      expect(stage17.sampleCount, 2645);
      final stage18a = await repository.profile((await guide.stage(22))!);
      expect(stage18a.sampleCount, 2338);
      final stage18b = await repository.profile((await guide.stage(23))!);
      expect(stage18b.sampleCount, 2646);
      final stage19a = await repository.profile((await guide.stage(24))!);
      expect(stage19a.sampleCount, 2609);
      final stage19b = await repository.profile((await guide.stage(25))!);
      expect(stage19b.sampleCount, 2372);
      final stage20 = await repository.profile((await guide.stage(26))!);
      expect(stage20.sampleCount, 1876);
      expect(stage20.missingPaths, isEmpty);
      expect(stage19a.missingPaths, isEmpty);
      expect(stage18b.missingPaths, isEmpty);
      expect(stage18a.missingPaths, isEmpty);
      expect(stage17.missingPaths, isEmpty);
      expect(river16.missingPaths, isEmpty);
      expect(road16.missingPaths, isEmpty);
      expect(stage15.missingPaths, isEmpty);
      expect(stage14.missingPaths, isEmpty);
      expect(stage13.missingPaths, isEmpty);
      expect(river.missingPaths, isEmpty);
      expect(stage12.missingPaths, isEmpty);
      expect(stage11.missingPaths, isEmpty);
      expect(stage10.missingPaths, isEmpty);

      expect(stage9.missingPaths, isEmpty);

      expect(stage8.missingPaths, isEmpty);

      expect(stage7.missingPaths, isEmpty);

      expect((await guide.route((await guide.stage(6))!)).points.length, 896);
      final db = await local.database;
      expect(
        (await db.rawQuery(
          'SELECT count(*) n FROM elevation_points',
        )).single['n'],
        56135,
      );
    },
  );

  test(
    'nearby elevation uses supplied sample and rejects poor or distant fixes',
    () async {
      final profile = await ElevationRepository(
        guide,
      ).profile((await guide.stage(1))!);
      final point = profile.sections.first.points[10];
      expect(
        profile.nearest(point.position)!.point.elevationMetres,
        point.elevationMetres,
      );
      expect(profile.nearest(point.position, accuracy: 51), isNull);
      expect(profile.nearest(const LatLng(51.5, 0)), isNull);
      final stage5 = await ElevationRepository(
        guide,
      ).profile((await guide.stage(5))!);
      final before = stage5.sections[2].points.last.position;
      final after = stage5.sections[3].points.first.position;
      final middle = LatLng(
        (before.latitude + after.latitude) / 2,
        (before.longitude + after.longitude) / 2,
      );
      final isolated = ElevationProfile(
        stage5.stage,
        [
          ElevationSection(stage5.sections[2].path, [
            stage5.sections[2].points.last,
          ], 0),
          ElevationSection(stage5.sections[3].path, [
            stage5.sections[3].points.first,
          ], 0),
        ],
        [],
        [],
      );
      expect(isolated.nearest(middle), isNotNull);
    },
  );

  test('older database gracefully has no profiles', () async {
    final file = File('${temporary.path}/old.sqlite');
    await File('assets/database/camino.sqlite').copy(file.path);
    final db = await databaseFactoryFfi.openDatabase(file.path);
    await db.execute('DROP TABLE elevation_points');
    await db.close();
    final old = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: '${temporary.path}/old',
      loadAsset: file.readAsBytes,
    );
    try {
      final repository = CaminoRepository(old);
      final profile = await ElevationRepository(
        repository,
      ).profile((await repository.stage(1))!);
      expect(profile.sections, isEmpty);
      expect(profile.missingPaths.length, 8);
    } finally {
      await old.close();
    }
  });

  test(
    'matches at 100 metres but rejects positions beyond 200 metres',
    () async {
      final profile = await ElevationRepository(
        guide,
      ).profile((await guide.stage(1))!);
      final first = profile.sections.first;
      final point = first.points.first;
      final isolated = ElevationProfile(
        profile.stage,
        [
          ElevationSection(first.path, [point], 0),
        ],
        [],
        [],
      );
      expect(
        isolated.nearest(
          LatLng(point.position.latitude + .0009, point.position.longitude),
        ),
        isNotNull,
      );
      expect(
        isolated.nearest(
          LatLng(point.position.latitude + .002, point.position.longitude),
        ),
        isNull,
      );
      expect(isolated.nearest(point.position, accuracy: 51), isNull);
    },
  );

  test('location annotations use nearby samples on their own paths', () async {
    final profile = await ElevationRepository(
      guide,
    ).profile((await guide.stage(1))!);
    expect(
      profile.landmarks.map((mark) => mark.location.id),
      containsAll([1, 9]),
    );
    expect(
      profile.landmarks.every(
        (mark) =>
            mark.match.distanceFromRoute <=
            ElevationProfile.maximumLandmarkMetres,
      ),
      isTrue,
    );
    final partial = await ElevationRepository(
      guide,
    ).profile((await guide.stage(6))!);
    expect(
      partial.landmarks.any(
        (mark) => mark.location.id == partial.stage.finishLocationId,
      ),
      isTrue,
    );
  });

  test('Reliegos is labelled on both stage 19 alternatives', () async {
    final repository = ElevationRepository(guide);
    for (final stageId in [24, 25]) {
      final profile = await repository.profile((await guide.stage(stageId))!);
      final reliegos = profile.landmarks.singleWhere(
        (mark) => mark.location.id == 133,
      );
      expect(
        reliegos.match.distanceFromRoute,
        lessThanOrEqualTo(ElevationProfile.maximumLandmarkMetres),
      );
      if (stageId == 25) {
        expect(reliegos.match.distanceFromRoute, lessThan(10));
        expect(reliegos.match.point.pathId, anyOf(129, 130));
        expect(reliegos.match.chartDistance, inInclusiveRange(17000, 19000));
      }
    }
  });

  testWidgets('phone chart renders, accepts taps, and exports visual check', (
    tester,
  ) async {
    late ElevationProfile profile;
    final font = File(
      '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/arial.ttf',
    );
    if (font.existsSync()) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      });
    }
    await tester.runAsync(() async {
      profile = await ElevationRepository(
        guide,
      ).profile((await guide.stage(1))!);
    });
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    ElevationPoint? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Stage 1 elevation',
                    style: TextStyle(fontFamily: 'Roboto'),
                  ),
                  ElevationChart(
                    profile: profile,
                    current: profile.nearest(
                      profile.sections.first.points[100].position,
                    ),
                    onSelect: (point) => selected = point,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('elevation-canvas')));
    expect(selected, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    final beforePan = viewer.transformationController!.value.clone();
    await tester.drag(find.byType(InteractiveViewer), const Offset(-30, -10));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value, isNot(beforePan));
    await tester.tap(find.text('Reset view'));
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/elevation_demo').create(recursive: true);
      await File(
        'build/elevation_demo/chart_preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets(
    'stage view loads imported samples with chart and inspection control',
    (tester) async {
      final stage = await tester.runAsync(() => guide.stage(6));
      await tester.pumpWidget(
        MaterialApp(
          home: ElevationScreen(repository: guide, stage: stage),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(find.byType(ElevationChart), findsOneWidget);
      expect(find.text('Missing elevation data for paths: 43.'), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(Slider),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
