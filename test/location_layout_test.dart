import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/ui/location_links.dart';
import 'package:camino_app/ui/app_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'location links resolve real names and alternate prior and next branches',
    (tester) async {
      final temporary = Directory.systemTemp.createTempSync('camino_links_');
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: temporary.path,
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      final repository = CaminoRepository(local);
      try {
        Future<void> show(int id) async {
          final places = await tester.runAsync(
            () => repository.locationsByIds({id}),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LocationLinks(
                  repository: repository,
                  location: places![id]!,
                ),
              ),
            ),
          );
          for (var i = 0; i < 30; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump();
            if (find.byType(TextButton).evaluate().isNotEmpty) break;
          }
        }

        await show(1);
        expect(find.text('Next location: Huntto'), findsOneWidget);
        expect(find.text('Alternate next location: Arnéguy'), findsOneWidget);
        expect(find.textContaining('Prior location:'), findsNothing);
        await show(9);
        expect(find.textContaining('Prior location:'), findsOneWidget);
        expect(
          find.textContaining('Alternate prior location:'),
          findsOneWidget,
        );
        expect(find.text('Next location: Burguete'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          await local.close();
          await temporary.delete(recursive: true);
        });
      }
    },
  );

  testWidgets(
    'system navigation inset is reserved once for all route content',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const bodyKey = Key('body');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 48),
              viewPadding: EdgeInsets.only(bottom: 48),
            ),
            child: AppViewport(child: child!),
          ),
          home: const Scaffold(body: SizedBox.expand(key: bodyKey)),
        ),
      );
      expect(tester.getBottomRight(find.byKey(bodyKey)).dy, 752);
      final context = tester.element(find.byKey(bodyKey));
      expect(MediaQuery.paddingOf(context).bottom, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('alternate prior spelling is accepted', () {
    expect(
      Location.fromRow({'ID': 1, 'altProrLoc': 4}).alternativePriorLocationId,
      4,
    );
  });
}
