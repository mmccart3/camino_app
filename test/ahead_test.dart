import 'dart:io';
import 'test_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/services/ahead_of_me.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/ui/ahead_screen.dart';

StageRoute fixture({bool missingMetric = false, bool valid = true}) =>
    StageRoute(
      stage: Stage.fromRow({
        'ID': 1,
        'stageName': 'Test',
        'stageStartLocationID': 1,
        'stageFinishLocationID': 3,
      }),
      paths: [
        for (var i = 1; i <= 2; i++)
          Path.fromRow({
            'pathID': i,
            'stageID': 1,
            'originLoc': i,
            'destinationLoc': i + 1,
          }),
      ],
      locations: [
        for (var i = 1; i <= 3; i++)
          Location.fromRow({'ID': i, 'locationName': 'Place $i'}),
      ],
      segments: [],
      points: [
        for (var i = 0; i < 5; i++)
          TrackPoint.fromRow({
            'track_point_id': i,
            'pathID': i <= 2 ? 1 : 2,
            'previous_track_point_id': i - 1,
            'latitude': 43.0,
            'longitude': -1.0 + i * .001,
            'distance_3d_meters': missingMetric && i == 2 ? null : 100.0,
            'weighted_distance': 460.0,
          }),
      ],
      issues: valid ? [] : ['Missing tracks'],
      locationsOrdered: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'sums incoming metrics only after user point and omits passed places',
    () {
      final service = AheadOfMeService();
      final ahead = service.calculate(fixture(), 1, 4.6);
      expect(ahead.map((p) => p.location.id), [2, 3]);
      expect(ahead.map((p) => p.metres), [100, 300]);
      expect(ahead.first.walkingTime!.inSeconds, 100);
      expect(ahead.last.walkingTime!.inSeconds, 300);
      expect(service.calculate(fixture(), 2, 4.6).map((p) => p.location.id), [
        3,
      ]);
      expect(service.calculate(fixture(), 4, 4.6), isEmpty);
      expect(
        service.calculate(fixture(), 1, 2.3).last.walkingTime!.inSeconds,
        600,
      );
    },
  );
  test(
    'missing distance stays unavailable without hiding independent time',
    () {
      final result = AheadOfMeService().calculate(
        fixture(missingMetric: true),
        1,
        4.6,
      );
      expect(result.every((p) => p.metres == null), isTrue);
      expect(result.last.walkingTime!.inSeconds, 300);
      expect(
        AheadOfMeService().calculate(fixture(valid: false), 0, 4.6),
        isEmpty,
      );
    },
  );
  testWidgets(
    'offline preview shows upcoming locations and supports service filter',
    (tester) async {
      sqfliteFfiInit();
      final folder = Directory.systemTemp.createTempSync('ahead_test_');
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: folder.path,
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      final repository = CaminoRepository(local);
      try {
        final stage = await tester.runAsync(() => repository.stage(1));
        await tester.pumpWidget(
          MaterialApp(
            home: AheadScreen(
              repository: repository,
              settings: SettingsService(preferences: MemoryPreferences()),
              stage: stage!,
            ),
          ),
        );
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
        await tester.tap(find.text('Preview from stage start'));
        await tester.pumpAndSettle();
        expect(find.text('Huntto'), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Pharmacy'));
        await tester.pumpAndSettle();
        expect(find.text('Huntto'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          await local.close();
          await folder.delete(recursive: true);
        });
      }
    },
  );
}
