import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/services/safe_links.dart';
import 'package:camino_app/ui/contact_links.dart';
import 'package:camino_app/ui/albergue_facilities.dart';

void main() {
  test('email trims database whitespace and cannot inject mail headers', () {
    expect(
      SafeLinks.emailAddress(' guest+camino@example.com\n'),
      'guest+camino@example.com',
    );
    final uri = Uri.parse(SafeLinks.emailUrl('guest+camino@example.com'));
    expect(uri.scheme, 'mailto');
    expect(Uri.decodeComponent(uri.path), 'guest+camino@example.com');
    expect(uri.hasQuery, isFalse);
    for (final value in [
      'NULL',
      '',
      'bad',
      'x@example.com?bcc=other@example.com',
      'x@example.com\r\nBcc: other@example.com',
    ]) {
      expect(SafeLinks.emailAddress(value), isNull);
      expect(() => SafeLinks.emailUrl(value), throwsArgumentError);
    }
  });
  for (final private in [false, true]) {
    testWidgets('email link for private=$private', (tester) async {
      for (final address in ['guest@example.com\n', 'NULL']) {
        final row = <String, Object?>{
          'ID': 1,
          'locationID': 1,
          'albergueName': 'Test',
          'privateAccommName': 'Test',
          'email': address,
        };
        final Accommodation place = private
            ? PrivateAccommodation.fromRow(row)
            : Albergue.fromRow(row);
        final sent = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContactLinks(
                place: place,
                email: (value) async {
                  sent.add(value);
                },
              ),
            ),
          ),
        );
        if (address == 'NULL') {
          expect(find.byType(TextButton), findsNothing);
        } else {
          await tester.tap(find.text('Email guest@example.com'));
          await tester.pump();
          expect(sent, ['guest@example.com']);
        }
      }
    });
  }
  testWidgets('dorm count and all facility states remain distinct', (
    tester,
  ) async {
    final place = Albergue.fromRow({
      'ID': 1,
      'locationID': 1,
      'albergueName': 'Test',
      'numberOfDorms': 4,
      'washingMachineAvailable': 1,
      'dryingMachineAvailable': 0,
      'communalMealAvailable': null,
      'kitchenFacilitiesAvailable': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AlbergueFacilities(albergue: place)),
      ),
    );
    for (final label in [
      'Dormitories: 4',
      'Washing machine: Yes',
      'Dryer: No',
      'Communal meal: Not recorded',
      'Kitchen facilities: Yes',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Chip), findsNWidgets(4));
  });
}
