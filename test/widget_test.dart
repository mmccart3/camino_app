import 'package:package_info_plus/package_info_plus.dart';
import 'package:camino_app/services/map_tiles.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/ui/screens.dart';
import 'package:camino_app/ui/map_screen.dart';
import 'package:camino_app/ui/settings_screen.dart';
import 'test_support.dart';

void main() {
  test('native tile provider identifies app and surfaces HTTP errors', () {
    final provider = MapTiles.provider();
    expect(provider.headers['User-Agent'], 'CaminoGuideOfflineMVP/0.1.3');
    expect(provider.headers.containsKey('Cache-Control'), isFalse);
    expect(provider.headers.containsKey('Pragma'), isFalse);
    expect(provider.attemptDecodeOfHttpErrorResponses, isFalse);
    expect(provider.cachingProvider, isNull); // Library default disk cache.
    provider.dispose();
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late CaminoRepository repository;
  late SettingsService settings;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('camino_ui_');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: temporary.path,
      loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
    );
    repository = CaminoRepository(local);
    settings = SettingsService(preferences: MemoryPreferences());
  });
  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });
  Future<void> finishDatabaseWork(WidgetTester tester) async {
    await tester.pump();
    // SQLite FFI uses real asynchronous work; the fake clock cannot finish it.
    // Wait for loading to finish rather than assuming a fixed machine speed.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  }

  testWidgets('stage 1 map draws all 778 points with tiles off', (
    tester,
  ) async {
    late Stage stage;
    await tester.runAsync(() async {
      stage = (await repository.stage(1))!;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          initialOffline: false,
          repository: repository,
          settings: settings,
          stage: stage,
          initialTiles: false,
        ),
      ),
    );
    await finishDatabaseWork(tester);
    expect(find.byType(TileLayer), findsNothing);
    final line = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines
        .single;
    expect(line.points.length, 778);
    expect(line.points.first.latitude, 43.163667);
    expect(line.points.last.latitude, 43.010444);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'basemap loads by default and can be switched off without losing the route',
    (tester) async {
      late Stage stage;
      await tester.runAsync(() async {
        stage = (await repository.stage(1))!;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            initialOffline: false,
            repository: repository,
            settings: settings,
            stage: stage,
            tileProvider: TestTileProvider(),
          ),
        ),
      );
      await finishDatabaseWork(tester);
      expect(find.byType(TileLayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FlutterMap),
          matching: find.text('© OpenStreetMap contributors'),
        ),
        findsOneWidget,
      );
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
      toggle.onChanged!(false);
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsNothing);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .single
            .points
            .length,
        778,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final status in [403, 429]) {
    testWidgets('HTTP $status pauses maps for the session and retains route', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      MapTiles.blockedStatus = null;
      addTearDown(() {
        MapTiles.blockedStatus = null;
      });
      late Stage stage;
      await tester.runAsync(() async {
        stage = (await repository.stage(1))!;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            initialOffline: false,
            repository: repository,
            settings: settings,
            stage: stage,
            tileProvider: TestTileProvider(),
          ),
        ),
      );
      await finishDatabaseWork(tester);
      expect(tester.widget<TileLayer>(find.byType(TileLayer)).panBuffer, 0);
      final dynamic state = tester.state(find.byType(MapScreen));
      state.tileError(
        NetworkImageLoadException(
          statusCode: status,
          uri: Uri.parse('https://tile.openstreetmap.org/1/0/0.png'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsNothing);
      expect(find.textContaining('returned HTTP $status'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(find.byType(PolylineLayer), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            initialOffline: false,
            repository: repository,
            settings: settings,
            stage: stage,
            tileProvider: TestTileProvider(),
          ),
        ),
      );
      await finishDatabaseWork(tester);
      expect(find.byType(TileLayer), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('stage without tracks shows markers and disables full guidance', (
    tester,
  ) async {
    late Stage stage;
    await tester.runAsync(() async {
      stage = (await repository.stage(6))!;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          initialOffline: false,
          repository: repository,
          settings: settings,
          stage: stage,
          initialTiles: false,
        ),
      ),
    );
    await finishDatabaseWork(tester);
    expect(find.text('Full-stage guidance unavailable'), findsOneWidget);
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      isEmpty,
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isNotEmpty,
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('stage 1 displays the updated offline elevation chart', (
    tester,
  ) async {
    late Stage stage;
    await tester.runAsync(() async {
      stage = (await repository.stage(1))!;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: StageDetailScreen(
          repository: repository,
          settings: settings,
          stage: stage,
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/stage_maps/stage_1.jpg'),
        tester.element(find.byType(StageDetailScreen)),
      );
      await precacheImage(
        const AssetImage('assets/elevation_charts/stage_1.png'),
        tester.element(find.byType(StageDetailScreen)),
      );
    });
    await finishDatabaseWork(tester);
    await tester.scrollUntilVisible(
      find.text('Published elevation chart'),
      700,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/elevation_charts/stage_1.png'),
        tester.element(find.text('Published elevation chart')),
      );
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/elevation_charts/stage_1.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Image unavailable in this app version.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('home opens real stage and location details', (tester) async {
    await tester.runAsync(() async {
      await local.database;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, settings: settings),
      ),
    );
    // Decode the bundled map outside the fake test clock before navigating.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/stage_maps/stage_1.jpg'),
        tester.element(find.byType(HomeScreen)),
      );
    });
    expect(find.textContaining('fictional'), findsNothing);
    await tester.tap(find.text('Explore stages'));
    await finishDatabaseWork(tester);
    await tester.tap(find.text('Saint-Jean-Pied-de-Port to Roncesvalles'));
    await finishDatabaseWork(tester);
    expect(
      find.text('Full-stage track geometry is available.'),
      findsOneWidget,
    );
    await tester.tap(find.text('St Jean Pied de Port'));
    await finishDatabaseWork(tester);
    expect(find.text('St Jean Pied de Port'), findsOneWidget);
    expect(find.byType(LocationDetailScreen), findsOneWidget);
    expect(find.text('Navigate here offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'accommodation screens handle absent photos and booking sentinels',
    (tester) async {
      late Albergue hostel;
      late PrivateAccommodation private;
      await tester.runAsync(() async {
        hostel = (await repository.albergues(1)).first;
        private = (await repository.privateAccommodation(1)).first;
      });
      await tester.pumpWidget(
        MaterialApp(home: AlbergueDetailScreen(albergue: hostel)),
      );
      await tester.pumpAndSettle();
      final bedSummary = find.textContaining('32 beds');
      await tester.scrollUntilVisible(bedSummary, 250);
      expect(bedSummary, findsOneWidget);
      expect(find.text('Open booking website'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateAccommodationDetailScreen(accommodation: private),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open booking website'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('settings saves walking pace locally', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Camino',
      packageName: 'com.example.camino_app',
      version: '0.2.0',
      buildNumber: '5',
      buildSignature: '',
    );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.min, 1.0);
    expect(slider.max, 8.5);
    expect(slider.divisions, 75);
    slider.onChanged!(8.5);
    await tester.pump();
    await tester.tap(find.text('Save pace'));
    await tester.pumpAndSettle();
    expect(settings.paceKmh, 8.5);
    expect(find.text('Walking pace saved on this device.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class TestTileProvider extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNYtfvMfwAHdQMxTAUe1QAAAABJRU5ErkJggg==',
    ),
  );
}
