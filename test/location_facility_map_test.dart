import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart' hide Row;
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/ui/app_theme.dart';
import 'package:camino_app/ui/location_facility_map_layer.dart';
import 'test_support.dart';

void main() {
  final cafe = Location.fromRow({
    'ID': 1,
    'locationName': 'A Serra',
    'latitude': 42.77099,
    'longitude': -7.46704,
    'hasBarCafe': 1,
    'hasPharmacy': 0,
  });
  final pharmacy = Location.fromRow({
    'ID': 2,
    'locationName': 'Pharmacy village',
    'latitude': 42.772,
    'longitude': -7.467,
    'hasPharmacy': 1,
    'hasGroceryStore': 1,
  });

  testWidgets(
    'database cafe badge is visible at zoom 12 without tiles and remains tappable',
    (tester) async {
      final settings = SettingsService(preferences: MemoryPreferences());
      Location? opened;
      Future<void> display(double zoom) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCaminoTheme(),
            home: Scaffold(
              body: FlutterMap(
                key: ValueKey(zoom),
                options: MapOptions(
                  initialCenter: cafe.position!,
                  initialZoom: zoom,
                ),
                children: [
                  LocationFacilityMapLayer(
                    locations: [cafe],
                    settings: settings,
                    onTap: (value) => opened = value,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await display(12);
      expect(find.byType(TileLayer), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-1-hasBarCafe')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_pharmacy_outlined), findsNothing);
      expect(find.text('A Serra'), findsOneWidget);
      final size = tester.getSize(find.byType(LocationFacilityMarker));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(LocationFacilityMarker));
      expect(opened, cafe);
      await display(11);
      expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
      expect(find.text('A Serra'), findsNothing);
      await display(10.9);
      expect(find.byIcon(Icons.local_cafe_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
  );

  testWidgets('Show filters persist and highlight matching locations only', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final settings = SettingsService(preferences: preferences);
    expect(settings.mapFacilities, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCaminoTheme(),
        home: Scaffold(
          appBar: AppBar(actions: [MapFacilityFilter(settings: settings)]),
          body: FlutterMap(
            options: MapOptions(initialCenter: cafe.position!, initialZoom: 12),
            children: [
              LocationFacilityMapLayer(
                locations: [cafe, pharmacy],
                settings: settings,
                onTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Pharmacies'),
    );
    await tester.pumpAndSettle();
    final markers = tester
        .widgetList<LocationFacilityMarker>(find.byType(LocationFacilityMarker))
        .toList();
    expect(markers.singleWhere((m) => m.location.id == 1).highlighted, isFalse);
    expect(markers.singleWhere((m) => m.location.id == 2).highlighted, isTrue);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
    final reloaded = SettingsService(preferences: preferences);
    await reloaded.load();
    expect(reloaded.mapFacilities, {'hasPharmacy'});
    await reloaded.setMapFacility('hasPharmacy', false);
    await settings.load();
    expect(settings.mapFacilities, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    reloaded.dispose();
  });
}
