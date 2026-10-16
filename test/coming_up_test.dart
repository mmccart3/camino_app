import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/services/ahead_of_me.dart';
import 'package:camino_app/services/next_services.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/services/walking_time.dart';
import 'package:camino_app/ui/coming_up_card.dart';
import 'package:camino_app/ui/ahead_screen.dart';
import 'ahead_test.dart' show fixture;
import 'test_support.dart';

class TestRepository extends CaminoRepository {
  final StageRoute value;
  int loads = 0;
  TestRepository(this.value) : super(LocalDatabase());
  @override
  Future<StageRoute> route(Stage stage) async {
    loads++;
    return value;
  }

  @override
  Future<List<Albergue>> albergues(int locationId) async => [];
  @override
  Future<List<PrivateAccommodation>> privateAccommodation(
    int locationId,
  ) async => [];
}

StageRoute servicesRoute({bool empty = false}) {
  final r = fixture();
  return StageRoute(
    stage: r.stage,
    paths: r.paths,
    segments: r.segments,
    points: r.points,
    issues: r.issues,
    locationsOrdered: true,
    locations: [
      for (final l in r.locations)
        Location.fromRow({
          ...l.source,
          'hasBarCafe': !empty && l.id == 2 ? 1 : null,
          'hasPharmacy': !empty && l.id == 3 ? 1 : 0,
          'hasGroceryStore': !empty && l.id == 3 ? 1 : null,
        }),
    ],
  );
}

void main() {
  test('first positive service only, ignoring false and unknown', () {
    AheadPlace p(int id, Object? cafe, Object? pharmacy, Object? shop) =>
        AheadPlace(
          Location.fromRow({
            'ID': id,
            'hasBarCafe': cafe,
            'hasPharmacy': pharmacy,
            'hasGroceryStore': shop,
          }),
          100,
          const Duration(minutes: 2),
        );
    final result = NextServices.from([
      p(1, null, 0, null),
      p(2, 1, null, 0),
      p(3, 1, 1, 1),
      p(4, 1, 1, 1),
    ]);
    expect(result.cafe!.location.id, 2);
    expect(result.pharmacy!.location.id, 3);
    expect(result.shop!.location.id, 3);
    expect(NextServices.from([]).isEmpty, isTrue);
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('card preview, GPS, speed, filters and cache at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final route = servicesRoute(),
          settings = SettingsService(preferences: MemoryPreferences());
      final repo = TestRepository(route);
      Widget screen({bool fixed = false}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: ComingUpCard(
            repository: repo,
            settings: settings,
            stage: route.stage,
            position: fixed ? route.points.first.position : null,
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text("Along today's route"), findsOneWidget);
      String estimate() => WalkingTime.format(
        AheadOfMeService()
            .calculate(route, 0, settings.paceKmh)
            .first
            .walkingTime!,
      );
      expect(find.textContaining(estimate()), findsWidgets);
      final old = estimate();
      await settings.setPace(1.0);
      await tester.pumpAndSettle();
      expect(estimate(), isNot(old));
      expect(find.textContaining(estimate()), findsWidgets);
      await tester.pumpWidget(screen(fixed: true));
      await tester.pumpAndSettle();
      expect(find.text('Coming up on your route'), findsOneWidget);
      expect(repo.loads, 1);
      await tester.tap(find.text('Place 2'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AheadScreen>(find.byType(AheadScreen)).initialFilter,
        'Café',
      );
      expect(find.textContaining(estimate()), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('no recorded services warns about supplies', (tester) async {
    final r = servicesRoute(empty: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComingUpCard(
            repository: TestRepository(r),
            settings: SettingsService(preferences: MemoryPreferences()),
            stage: r.stage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Nothing recorded for the rest of this stage. Carry food and water.',
      ),
      findsOneWidget,
    );
  });
}
