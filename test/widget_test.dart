import 'package:flutter/services.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/ui/elevation_chart.dart';
import 'package:camino_app/ui/elevation_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late CaminoRepository repository;
  late SettingsService settings;
  late MemoryPreferences preferences;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('camino/compass'),
          (_) async => null,
        );
    temporary = await Directory.systemTemp.createTemp('camino_ui_');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: temporary.path,
      loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
    );
    repository = CaminoRepository(local);
    preferences = MemoryPreferences();
    settings = SettingsService(preferences: preferences);
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

  testWidgets('stage 1 map draws all 775 points with tiles off', (
    tester,
  ) async {
    late Stage stage;
    await tester.runAsync(() async {
      stage = (await repository.stage(1))!;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          showOfflineMap: false,
          repository: repository,
          settings: settings,
          stage: stage,
        ),
      ),
    );
    await finishDatabaseWork(tester);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text('Online basemap'), findsNothing);
    expect(find.text('Offline stages 1–5 map'), findsNothing);
    expect(
      find.textContaining('Offline maps only. Bundled coverage:'),
      findsNothing,
    );
    expect(find.byType(SwitchListTile), findsNothing);
    final line = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines
        .single;
    expect(line.points.length, 775);
    expect(line.points.first.latitude, 43.1634);
    expect(line.points.last.latitude, 43.010444);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'stage without tracks shows markers and marks full guidance unavailable',
    (tester) async {
      late Stage stage;
      await tester.runAsync(() async {
        stage = (await repository.stage(7))!;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            showOfflineMap: false,
            repository: _NoTracksRepository(local),
            settings: settings,
            stage: stage,
          ),
        ),
      );
      await finishDatabaseWork(tester);
      await tester.scrollUntilVisible(
        find.text('Full-stage guidance unavailable'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Full-stage guidance unavailable'), findsOneWidget);
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        isEmpty,
      );
      expect(
        tester
            .widgetList<MarkerLayer>(find.byType(MarkerLayer))
            .expand((layer) => layer.markers),
        isNotEmpty,
      );
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('stage 1 opens the generated elevation chart directly', (
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
    await finishDatabaseWork(tester);
    final elevation = find.widgetWithText(OutlinedButton, 'Elevation');
    await tester.ensureVisible(elevation);
    await tester.tap(elevation);
    await finishDatabaseWork(tester);
    expect(find.byType(ElevationScreen), findsOneWidget);
    expect(find.byType(ElevationChart), findsWidgets);
    expect(find.byKey(const ValueKey('elevation-canvas')), findsWidgets);
    expect(tester.takeException(), isNull);
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
    await finishDatabaseWork(tester);
    await tester.tap(find.text('Choose a stage'));
    await finishDatabaseWork(tester);
    expect(find.text('Search a town or stage'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'zz-no-such-stage');
    await tester.pump();
    expect(find.text('No matching stages'), findsOneWidget);
    await tester.tap(find.text('Show all stages'));
    await tester.pump();
    await tester.tap(find.text('Saint-Jean-Pied-de-Port to Roncesvalles'));
    await finishDatabaseWork(tester);
    expect(find.text('Places along the way'), findsOneWidget);
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
      await finishDatabaseWork(tester);
      final bedSummary = find.textContaining('32 beds');
      await tester.scrollUntilVisible(bedSummary, 250);
      expect(bedSummary, findsOneWidget);
      expect(find.text('Open Booking.com webpage'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateAccommodationDetailScreen(accommodation: private),
        ),
      );
      await finishDatabaseWork(tester);
      expect(find.text('Open Booking.com webpage'), findsOneWidget);
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
    expect(slider.min, 2.0);
    expect(slider.max, 7.0);
    expect(slider.divisions, isNull);
    slider.onChanged!(7.0);
    await tester.pump();
    slider.onChangeEnd!(7.0);
    await tester.pumpAndSettle();
    expect(settings.paceKmh, 7.0);
    final reloaded = SettingsService(preferences: preferences);
    await reloaded.load();
    expect(reloaded.paceKmh, 7.0);
    final alertSlider = tester.widget<Slider>(find.byType(Slider).last);
    alertSlider.onChanged!(120);
    alertSlider.onChangeEnd!(120);
    await tester.pumpAndSettle();
    await reloaded.load();
    expect(reloaded.offRouteMetres, 120);

    expect(find.text('Saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Missing-track behaviour is independent of the ever-growing bundled guide.
class _NoTracksRepository extends CaminoRepository {
  _NoTracksRepository(super.local);
  @override
  Future<StageRoute> route(Stage stage) async {
    final real = await super.route(stage);
    return RouteAssembler.assemble(stage, real.paths, real.locations, {});
  }
}
