import 'test_support.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/ui/camino_plan_screen.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/services/camino_plan_store.dart';
import 'package:camino_app/services/walking_day_store.dart';
import 'package:camino_app/ui/planned_stay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late CaminoPlanStore store;
  late int plan;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('camino_plan_test_');
    store = CaminoPlanStore(
      path: '${dir.path}/user.sqlite',
      factory: databaseFactoryFfi,
    );
    plan = await store.create('My Camino');
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  ItineraryDay day({
    int id = 0,
    int end = 2,
    int start = 1,
    bool estimated = true,
    String date = '2027-05-01',
  }) => ItineraryDay(
    id: id,
    planId: plan,
    order: 0,
    startId: start,
    endId: end,
    startName: 'Start',
    endName: 'Destination',
    metres: estimated ? 23456 : null,
    seconds: estimated ? 19000 : null,
    route: SavedWalkingDay(
      'route',
      estimated ? [1, 2] : [],
      4.2,
      date,
      departureMinutes: 480,
      breaks: estimated ? {3: 30} : {},
    ),
  );
  const stay = PlannedStay(
    id: 7,
    kind: 'albergue',
    name: 'Pilgrim house',
    status: 'Confirmed',
    reference: 'ABC',
    notes: 'Late arrival',
  );
  test(
    'plans and booking snapshots survive reopen independently of guide files',
    () async {
      final id = await store.saveDay(day());
      await store.setStay(id, stay, locationId: 2);
      await store.close();
      expect((await store.plans()).single.name, 'My Camino');
      final restored = (await store.days(plan)).single;
      expect(restored.route.breaks, {3: 30});
      expect(restored.stay!.reference, 'ABC');
      expect(restored.totalDuration, const Duration(seconds: 20800));
      expect(restored.metres, 23456);
    },
  );
  test(
    'route edits preserve latest booking until destination changes',
    () async {
      final id = await store.saveDay(day());
      await store.setStay(id, stay, locationId: 2);
      await store.saveDay(day(id: id));
      expect((await store.days(plan)).single.stay!.status, 'Confirmed');
      await store.saveDay(day(id: id, end: 4));
      expect((await store.days(plan)).single.stay, isNull);
      await expectLater(
        store.setStay(id, stay, locationId: 2),
        throwsStateError,
      );
    },
  );
  test(
    'incomplete days retain destinations with no fabricated estimates',
    () async {
      await store.saveDay(day(estimated: false));
      final restored = (await store.days(plan)).single;
      expect(restored.hasEstimate, false);
      expect(restored.route.pathIds, isEmpty);
      expect(restored.metres, isNull);
      expect(restored.seconds, isNull);
    },
  );
  test('order, continuity warnings and cascading deletion', () async {
    await store.saveDay(day());
    await store.saveDay(day(start: 2, end: 4, date: '2027-05-02'));
    var rows = await store.days(plan);
    expect(rows[1].order, 1);
    expect(rows[1].warningAfter(rows[0]), isNull);
    expect(day(start: 9).warningAfter(rows[0]), contains('does not start'));
    expect(day(start: 2).warningAfter(rows[0]), contains('Check dates'));
    final other = await store.create('Other trip');
    await store.deletePlan(plan);
    expect(await store.days(plan), isEmpty);
    expect((await store.plans()).single.id, other);
  });
  testWidgets(
    'accommodation choice records private type and manually confirmed status',
    (tester) async {
      final id = await tester.runAsync(() => store.saveDay(day()));
      final accommodation = PrivateAccommodation.fromRow({
        'ID': 7,
        'locationID': 2,
        'privateAccommName': 'Hotel test',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddStayToPlanButton(place: accommodation, store: store),
          ),
        ),
      );
      await tester.tap(find.text('Add to my Camino plan'));
      for (
        var i = 0;
        i < 30 &&
            find.text('Choose the night for this stay').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('My Camino |'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Considering'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'BOOK-123');
      await tester.tap(find.text('Save stay'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      final rows = await tester.runAsync(() => store.days(plan));
      expect(rows!.single.id, id);
      expect(rows.single.stay!.kind, 'private');
      expect(rows.single.stay!.status, 'Confirmed');
      expect(rows.single.stay!.reference, 'BOOK-123');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'itinerary renders an unestimated booked night on a narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        final id = await store.saveDay(day(estimated: false));
        await store.setStay(id, stay, locationId: 2);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CaminoPlanScreen(
            repository: CaminoRepository(
              LocalDatabase(factory: databaseFactoryFfi),
            ),
            settings: SettingsService(preferences: MemoryPreferences()),
            plan: CaminoPlan(plan, 'My Camino'),
            store: store,
          ),
        ),
      );
      for (
        var i = 0;
        i < 30 && find.textContaining('Stay: Pilgrim house').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Day 1 | 2027-05-01'), findsOneWidget);
      expect(
        find.text('Distance and walking time: estimates unavailable'),
        findsOneWidget,
      );
      expect(find.text('Stay: Pilgrim house | Confirmed'), findsOneWidget);
      expect(find.text('Reference: ABC'), findsOneWidget);
      expect(find.text('Location and accommodation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
