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
      expect(stage1.sampleCount, 2419);
      expect(stage1.sections.length, 8);
      expect(stage1.sections.first.points.first.distanceMetres, 0);
      expect(stage1.sections.first.points.last.distanceMetres, 5270);
      expect(stage1.sections[1].points.first.sequence, 0);
      expect(stage1.sections[1].points.first.distanceMetres, 0);
      final stage5 = await repository.profile((await guide.stage(5))!);
      expect(stage5.issues.any((i) => i.contains('35–36')), isTrue);
      expect(stage5.issues.any((i) => i.contains('36–37')), isTrue);
      final stage6 = await repository.profile((await guide.stage(6))!);
      expect(stage6.missingPaths, contains(43));
      expect((await guide.route((await guide.stage(6))!)).points.length, 739);
      final db = await local.database;
      expect(
        (await db.rawQuery(
          'SELECT count(*) n FROM elevation_points',
        )).single['n'],
        12520,
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
      expect(isolated.nearest(middle), isNull);
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
      profile.landmarks.every((mark) => mark.match.distanceFromRoute <= 150),
      isTrue,
    );
    final partial = await ElevationRepository(
      guide,
    ).profile((await guide.stage(6))!);
    expect(
      partial.landmarks.any(
        (mark) => mark.location.id == partial.stage.finishLocationId,
      ),
      isFalse,
    );
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
      await Directory('../elevation_demo').create(recursive: true);
      await File(
        '../elevation_demo/chart_preview.png',
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
      await tester.scrollUntilVisible(
        find.text('Missing elevation data for paths: 43.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Missing elevation data for paths: 43.'),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
