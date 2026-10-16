import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/home_screen.dart';
import 'package:camino_app/ui/persistent_tabs.dart';
import 'package:camino_app/ui/app_theme.dart';
import 'package:camino_app/ui/app_logo.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/services/camino_plan_store.dart';
import 'test_support.dart';
import 'coming_up_test.dart' show TestRepository;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/services/ahead_of_me.dart';
import 'package:camino_app/services/walking_time.dart';
import 'package:camino_app/ui/coming_up_card.dart';
import 'package:camino_app/ui/today_progress.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('Today fits 360x740 at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('Figtree');
        for (final face in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'ExtraBold',
        ]) {
          font.addFont(
            File(
              'assets/fonts/Figtree-$face.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await font.load();
        await (FontLoader(
          'Fiesta',
        )..addFont(rootBundle.load('assets/fonts/Fiesta.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      sqfliteFfiInit();
      final folder = Directory.systemTemp.createTempSync('today_coming_');
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: folder.path,
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      final real = CaminoRepository(local);
      final stage = (await tester.runAsync(() => real.stage(1)))!;
      final route = (await tester.runAsync(() => real.route(stage)))!;
      final repository = TestRepository(route);
      final settings = SettingsService(preferences: MemoryPreferences());
      addTearDown(() async {
        await local.close();
        await folder.delete(recursive: true);
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCaminoTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: PersistentTabs(
              open: (_) => false,
              root: (_, index) => index == 0
                  ? HomeScreen(repository: repository, settings: settings)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      // Isolate the presentation from personal storage and GPS: seed the loaded
      // stage state after startup completes, without invoking either service.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
        final dynamic state = tester.state(find.byType(HomeScreen));
        if (state.loading == false) break;
      }
      final dynamic state = tester.state(find.byType(HomeScreen));
      state.setState(() {
        state.revision++;
        state.loading = false;
        state.planError = null;
        state.todayRoute = null;
        state.walkingDay = null;
        state.next = null;
        state.selectedStageTime = const Duration(hours: 8, minutes: 53);
        state.recent = Stage.fromRow({
          'ID': 1,
          'stageDisplayReference': '1a',
          'stageName': 'Saint Jean to Roncesvalles',
          'stageStartLocationID': 1,
          'stageFinishLocationID': 9,
          'stageDistanceInMetres': 24900.0,
          'stageTimeInMinutes': 435.0,
        });
        state.stageStart = Location.fromRow({
          'ID': 1,
          'locationName': 'St Jean Pied de Port',
        });
        state.stageEnd = Location.fromRow({
          'ID': 9,
          'locationName': 'Roncesvalles',
        });
      });
      await tester.pumpAndSettle();
      expect(find.text("Along today's route"), findsOneWidget);
      final cafe = AheadOfMeService()
          .calculate(route, 0, settings.paceKmh)
          .firstWhere((p) => p.location.hasBarCafe == true);
      expect(
        find.descendant(
          of: find.byType(ComingUpCard),
          matching: find.textContaining(WalkingTime.format(cafe.walkingTime!)),
        ),
        findsWidgets,
      );
      expect(find.byType(AppLogo), findsNothing);
      expect(find.text('One step at a time.'), findsNothing);
      expect(tester.takeException(), isNull);
      final nav = tester.getRect(find.byType(NavigationBar));
      final stageCard = find.ancestor(
        of: find.text('YOUR SELECTED STAGE'),
        matching: find.byType(Card),
      );
      expect(tester.getRect(stageCard).bottom, lessThanOrEqualTo(nav.top));
      final update = tester.getRect(find.widgetWithText(TextButton, 'Update'));
      expect(
        update.bottom,
        lessThanOrEqualTo(nav.top),
        reason: 'GPS Update must fit above the navigation',
      );
      for (final label in ['Ahead', 'Elevation', 'Diary']) {
        final button = tester.getRect(
          find.widgetWithText(OutlinedButton, label),
        );
        expect(button.height, greaterThanOrEqualTo(48));
      }
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('My Camino'),
      );
      expect(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 9),
            )
            .length,
        1,
      );
      final previewDirectory = Platform.environment['CAMINO_TODAY_PREVIEW_DIR'];
      if (previewDirectory != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$previewDirectory/today-$scale.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final firstService = find
          .descendant(
            of: find.byType(ComingUpCard),
            matching: find.text(cafe.location.name),
          )
          .first;
      expect(tester.getRect(firstService).bottom, lessThan(nav.top));
      expect(tester.takeException(), isNull);
      if (previewDirectory != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$previewDirectory/coming-up-$scale.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.widget<TodayProgress>(find.byType(TodayProgress)).onPosition!(
        route.points.first.position,
      );
      await tester.pumpAndSettle();
      expect(find.text('Coming up on your route'), findsOneWidget);
      state.setState(() {
        state.recent = null;
        state.selectedStageTime = null;
        state.plans = <CaminoPlan>[];
        state.hasSavedWalkingDays = false;
      });
      await tester.pumpAndSettle();
      expect(find.text('Plan your Camino'), findsOneWidget);
      expect(find.text('Choose a starting stage'), findsOneWidget);
      expect(find.text('Just browse the stages'), findsOneWidget);
      expect(find.text('YOUR SELECTED STAGE'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
