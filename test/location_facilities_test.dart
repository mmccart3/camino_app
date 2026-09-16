import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/data/local_database.dart';
import 'package:camino_app/data/camino_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/ui/location_facilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled service fields survive first-launch copy and repository query',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'camino_facilities_',
      );
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        directory: directory.path,
        loadAsset: () => File('assets/database/camino.sqlite').readAsBytes(),
      );
      try {
        final places = await CaminoRepository(local).locations(1);
        final start = places.singleWhere((place) => place.id == 1);
        expect(start.hasBarCafe, isTrue);
        expect(start.hasPharmacy, isTrue);
        expect(start.hasGroceryStore, isTrue);
        expect(start.source['hasBarCafeSource'], startsWith('OSM reviewed:'));
        final db = await local.database;
        final unknown = Location.fromRow(
          (await db.query(
            'locations',
            where: 'ID = ?',
            whereArgs: [290],
          )).single,
        );
        expect(unknown.hasBarCafe, isNull);
        expect(unknown.hasPharmacy, isNull);
        expect(unknown.hasGroceryStore, isNull);
      } finally {
        await local.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('older databases and unexpected flags remain unknown', () {
    final location = Location.fromRow({
      'ID': 1,
      'locationName': 'Village',
      'hasBarCafe': 2,
    });
    expect(location.hasBarCafe, isNull);
    expect(location.hasPharmacy, isNull);
    expect(location.hasGroceryStore, isNull);
  });
  testWidgets('shows large icons only for available services', (tester) async {
    final location = Location.fromRow({
      'ID': 1,
      'locationName': 'Village',
      'hasBarCafe': 1,
      'hasBarCafeSource': 'OSM reviewed: https://www.openstreetmap.org/node/1',
      'hasBarCafeCheckedAt': '2026-09-16T12:00:00Z',
      'hasPharmacy': 0,
      'hasPharmacySource': 'Owner checked',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationFacilities(location: location)),
      ),
    );
    expect(find.text('Bar / café'), findsOneWidget);
    expect(find.textContaining('Pharmacy'), findsNothing);
    expect(find.byIcon(Icons.local_pharmacy_outlined), findsNothing);
    expect(find.textContaining('Groceries'), findsNothing);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.local_cafe_outlined)).size,
      48,
    );
    expect(find.textContaining('Unknown means'), findsNothing);
    expect(
      find.textContaining('current operation are not confirmed'),
      findsNothing,
    );
    expect(find.byTooltip('Bar / café\nChecked: 2026-09-16'), findsOneWidget);
  });
  testWidgets('hides the entire section when no service is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationFacilities(
            location: Location.fromRow({
              'ID': 1,
              'locationName': 'Village',
              'hasBarCafe': 0,
            }),
          ),
        ),
      ),
    );
    expect(find.text('Local services'), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
