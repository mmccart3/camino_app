import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/models.dart' hide Row;
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/services/stage_walking_time.dart';
import 'package:camino_app/services/walking_time.dart';
import 'package:camino_app/ui/home_screen.dart';
import 'package:camino_app/ui/stage_list_screen.dart';
import 'test_support.dart';

class _Repository extends CaminoRepository {
  _Repository() : super(LocalDatabase());
  final example = Stage.fromRow({
    'ID': 1,
    'stageDisplayReference': '1a',
    'stageName': 'Test stage',
    'stageStartLocationID': 1,
    'stageFinishLocationID': 2,
    'stageDistanceInMetres': 24600.0,
    'stageTimeInMinutes': 406.0,
  });
  bool missingWeights = false;
  @override
  Future<List<Stage>> stages() async => [example];
  @override
  Future<List<Location>> locations(int stageId) async => [];
  @override
  Future<List<Path>> paths(int stageId) async => [];
  @override
  Future<StageRoute> route(Stage stage) async {
    final points = [
      for (var i = 0; i < 2; i++)
        TrackPoint.fromRow({
          'track_point_id': i + 1,
          'pathID': 1,
          'latitude': 43.0,
          'longitude': -1.0 + i * .0001,
          'weighted_distance': missingWeights
              ? null
              : (i == 0 ? 999999.0 : 120000.0),
        }),
    ];
    return StageRoute(
      stage: stage,
      paths: [],
      locations: [],
      segments: [points],
      points: points,
      issues: [],
      locationsOrdered: true,
    );
  }
}

void main() {
  testWidgets(
    'Today and Explore agree and refresh after walking speed changes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final settings = SettingsService(preferences: MemoryPreferences());
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: HomeScreen(repository: repository, settings: settings),
              ),
              Expanded(
                child: StageListScreen(
                  repository: repository,
                  settings: settings,
                ),
              ),
            ],
          ),
        ),
      );
      // Seed the presentation before waiting for animations: Home starts real
      // personal-storage work, which this repository fixture does not provide.
      await tester.pump();
      final dynamic home = tester.state(find.byType(HomeScreen));
      home.setState(() {
        home.revision++;
        home.loading = false;
        home.planError = null;
        home.recent = repository.example;
      });
      String? previous;
      for (final speed in [3.2, 4.2]) {
        await settings.setPace(speed);
        await tester.pumpAndSettle();
        final duration = WalkingTime.estimate(120000, speed)!;
        final formatted = WalkingTime.format(duration);
        expect(find.text(formatted), findsOneWidget);
        expect(find.text('$formatted walking'), findsOneWidget);
        if (previous != null) expect(formatted, isNot(previous));
        previous = formatted;
        expect(
          await stageWalkingTime(repository.example, repository, settings),
          duration,
        );
      }
      repository.missingWeights = true;
      await settings.setPace(3.2);
      await tester.pumpAndSettle();
      expect(find.text('Walking time unavailable'), findsOneWidget);
      expect(
        await stageWalkingTime(repository.example, repository, settings),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
  );
}
