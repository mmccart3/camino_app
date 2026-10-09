import 'test_support.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/services/walking_day.dart';
import 'package:camino_app/services/walking_day_store.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/services/walking_time.dart';
import 'package:camino_app/ui/walking_day_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('arrival clock handles rounding and crossing midnight', () {
    expect(
      walkingDayClock(480, const Duration(hours: 5, minutes: 37, seconds: 19)),
      '13:38',
    );
    expect(walkingDayClock(1410, const Duration(hours: 1)), '00:30 (+1 day)');
    expect(walkingDayClock(480, const Duration(hours: 48)), '08:00 (+2 days)');
  });
  test('older plans default to 08:00 and invalid times are rejected', () {
    final row = <String, dynamic>{
      'id': 'old',
      'paths': [129, 130],
      'pace': 4.2,
      'date': null,
    };
    expect(SavedWalkingDay.fromJson(row).departureMinutes, 480);
    expect(SavedWalkingDay.fromJson(row).breaks, isEmpty);
    expect(
      () => SavedWalkingDay.fromJson({
        ...row,
        'breaks': {'133': -1},
      }),
      throwsFormatException,
    );
    expect(
      () => SavedWalkingDay.fromJson({...row, 'departureMinutes': 1440}),
      throwsFormatException,
    );
  });
  sqfliteFfiInit();
  test('walking time uses hours and minutes with correct rounding', () {
    expect(
      formatWalkingDayTime(const Duration(minutes: 337, seconds: 19)),
      '5 hr 38 min',
    );
    expect(
      formatWalkingDayTime(const Duration(minutes: 59, seconds: 59)),
      '1 hr 0 min',
    );
    expect(formatWalkingDayTime(const Duration(minutes: 35)), '0 hr 35 min');
  });
  late Directory directory;
  late LocalDatabase local;
  late CaminoRepository repository;
  late WalkingDayPlanner planner;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('walking_day_');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
      loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
    );
    repository = CaminoRepository(local);
    planner = await WalkingDayPlanner.load(repository);
  });
  tearDownAll(() async {
    await local.close();
    await directory.delete(recursive: true);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cross-stage plan sums only recorded incoming segments', () async {
    final first = await repository.route((await repository.stage(16))!);
    final second = await repository.route((await repository.stage(17))!);
    final ids = [
      ...first.paths.map((p) => p.id),
      ...second.paths.map((p) => p.id),
    ];
    final day = planner.calculate(ids, 4.2);
    final points = [...first.points.skip(1), ...second.points.skip(1)];
    final distance = points.fold<double>(0, (s, p) => s + p.distance3dMeters!);
    final weight = points.fold<double>(0, (s, p) => s + p.weightedDistance!);
    expect(day.metres, closeTo(distance, .001));
    expect(day.walkingTime, WalkingTime.estimate(weight, 4.2));
    expect(day.profile.length, closeTo(day.metres, .001));
    expect(day.arrivalOffsets.length, day.places.length);
    expect(day.arrivalOffsets.first, Duration.zero);
    expect(day.arrivalOffsets.last, day.walkingTime);
    final firstWeight = first.points
        .skip(1)
        .fold<double>(0, (s, p) => s + p.weightedDistance!);
    expect(
      day.arrivalOffsets[first.paths.length],
      WalkingTime.estimate(firstWeight, 4.2),
    );
    for (var i = 1; i < day.arrivalOffsets.length; i++) {
      expect(day.arrivalOffsets[i] >= day.arrivalOffsets[i - 1], isTrue);
    }
    expect(day.places.first.id, first.stage.startLocationId);
    expect(day.places.last.id, second.stage.finishLocationId);
    expect(day.ascent, greaterThan(0));
    expect(day.descent, greaterThan(0));
    expect(
      planner.calculate(ids, 8.4).walkingTime.inSeconds,
      closeTo(day.walkingTime.inSeconds / 2, 1),
    );
  });
  test('stage 16 alternatives are separate selectable routes', () async {
    final stage = (await repository.stage(19))!;
    final options = planner.routes(
      stage.startLocationId,
      stage.finishLocationId,
    );
    expect(options.any((p) => p.contains(101) && p.contains(105)), isTrue);
    expect(options.any((p) => p.contains(503) && p.contains(506)), isTrue);
    for (final ids in options) {
      final day = planner.calculate(ids, 4.2);
      expect(day.metres, greaterThan(10000));
      expect(day.places.first.id, stage.startLocationId);
      expect(day.places.last.id, stage.finishLocationId);
    }
    expect(
      planner.routes(stage.finishLocationId, stage.startLocationId),
      isEmpty,
    );
    expect(
      planner.routes(stage.startLocationId, stage.startLocationId),
      isEmpty,
    );
  });
  test(
    'missing tracks and stale saved paths do not produce estimates',
    () async {
      final stage = (await repository.stage(27))!;
      expect(
        planner.routes(stage.startLocationId, stage.finishLocationId),
        isEmpty,
      );
      expect(() => planner.calculate([999999], 4.2), throwsStateError);
      expect(() => planner.calculate([101, 101], 4.2), throwsStateError);
      expect(() => planner.calculate([101], double.nan), throwsStateError);
      expect(() => planner.calculate([101, 129], 4.2), throwsStateError);
    },
  );
  test(
    'saved plans survive reload and deletion leaves other settings alone',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unrelated', 'keep');
      final store = WalkingDayStore();
      await store.save([
        const SavedWalkingDay(
          'one',
          [129, 130],
          4.2,
          '2026-10-09',
          departureMinutes: 435,
          breaks: {133: 30},
        ),
      ]);
      final loaded = await WalkingDayStore().load();
      expect(loaded.single.pathIds, [129, 130]);
      expect(loaded.single.date, '2026-10-09');
      expect(loaded.single.departureMinutes, 435);
      expect(loaded.single.breaks, {133: 30});
      await store.save([]);
      expect(await store.load(), isEmpty);
      await store.clear();
      expect(prefs.getString('unrelated'), 'keep');
    },
  );
  test('corrupt saved data is not silently overwritten', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WalkingDayStore.key, '{broken');
    await expectLater(WalkingDayStore().load(), throwsFormatException);
    expect(prefs.getString(WalkingDayStore.key), '{broken');
  });
  test('breaks delay later arrivals without changing walking time', () {
    final day = planner.calculate([129, 130], 4.2);
    final schedule = day.timetable({133: 30, 999999: 60});
    expect(schedule.arrivals[1], day.arrivalOffsets[1]);
    expect(
      schedule.departures[1],
      day.arrivalOffsets[1] + const Duration(minutes: 30),
    );
    expect(
      schedule.arrivals.last,
      day.walkingTime + const Duration(minutes: 30),
    );
    expect(schedule.totalBreak, const Duration(minutes: 30));
    expect(
      schedule.totalDuration,
      day.walkingTime + const Duration(minutes: 30),
    );
    expect(walkingDayClock(480, schedule.arrivals.last), '14:08');
    final faster = planner.calculate([129, 130], 8.4);
    expect(faster.timetable({133: 30}).totalBreak, const Duration(minutes: 30));
    expect(day.timetable({}).arrivals.last, day.walkingTime);
    expect(() => day.timetable({133: -1}), throwsArgumentError);
    expect(
      day.timetable({
        day.places.first.id: 60,
        day.places.last.id: 60,
      }).totalBreak,
      Duration.zero,
    );
  });

  testWidgets('planner opens saved day on a narrow phone and shows privacy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await WalkingDayStore().save([
      const SavedWalkingDay('one', [129, 130], 4.2, null),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: WalkingDayScreen(
          repository: repository,
          settings: SettingsService(preferences: MemoryPreferences()),
        ),
      ),
    );
    for (
      var i = 0;
      i < 30 && find.text('Choose starting place').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('Choose starting place'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No date | 08:00 | 4.2 km/h'),
      200,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No date | 08:00 | 4.2 km/h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No date | 08:00 | 4.2 km/h'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Update saved walking day'), 200);
    await tester.scrollUntilVisible(
      find.textContaining('hr 38 min walking'),
      -200,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('hr 38 min walking'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start: 08:00'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Start: 08:00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Approx. arrival: 13:38'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Approx. arrival: 13:38'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Add break'), -150);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add break'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add break'));
    await tester.pumpAndSettle();
    expect(find.text('Break at Reliegos'), findsOneWidget);
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Approx. arrival: 14:08'), 150);
    await tester.pumpAndSettle();
    expect(find.text('Approx. arrival: 14:08'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Update saved walking day'), 150);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Update saved walking day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update saved walking day'));
    await tester.pumpAndSettle();
    expect((await WalkingDayStore().load()).single.breaks, {133: 30});

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Walking-day privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Your walking-day privacy'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'itinerary editor returns a day without modifying standalone saves',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      SavedWalkingDay? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<SavedWalkingDay>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WalkingDayScreen(
                        repository: repository,
                        settings: SettingsService(
                          preferences: MemoryPreferences(),
                        ),
                        itineraryEditor: true,
                        initialDay: const SavedWalkingDay(
                          'itinerary',
                          [129, 130],
                          4.2,
                          '2027-05-01',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      for (
        var i = 0;
        i < 50 &&
            find.text('From: Calzadilla de los Hermanillos').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Flat-ground pace:').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Saved walking days'), findsNothing);
      await tester.scrollUntilVisible(find.text('Save itinerary day'), 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save itinerary day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save itinerary day'));
      await tester.pumpAndSettle();
      expect(result!.pathIds, [129, 130]);
      expect(result!.date, '2027-05-01');
      expect(await WalkingDayStore().load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
