import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/ui/screens.dart';

void main() {
  for (final private in [false, true]) {
    testWidgets('booking follows telephone for private=$private', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final row = <String, Object?>{
        'ID': 1,
        'locationID': 1,
        'albergueName': 'Test',
        'privateAccommName': 'Test',
        'tel1CountryCode': 34,
        'tel1PhoneNumber': 612345678,
        'albergueBookingDotComURL': 'https://www.booking.com/hotel/test.html',
        'privateAccommBookingDotComURL':
            'https://www.booking.com/hotel/test.html',
        'numberOfBeds': 46,
        'numberOfDorms': 5,
        'openingPeriod': 'Easter week till mid October (assumed)',
        'checkInTimes': '14:00 - 20:00 (assumed)',
      };
      final Accommodation place = private
          ? PrivateAccommodation.fromRow(row)
          : Albergue.fromRow(row);
      await tester.pumpWidget(
        MaterialApp(
          home: AccommodationDetail(place: place, kind: 'Test'),
        ),
      );
      final call = find.textContaining('Call +34');
      final booking = find.text('Open booking website');
      expect(call, findsOneWidget);
      expect(booking, findsOneWidget);
      expect(
        tester.getTopLeft(booking).dy,
        greaterThan(tester.getTopLeft(call).dy),
      );
      if (!private) {
        final beds = find.text('46 beds spread across 5 dormitories');
        expect(beds, findsOneWidget);
        expect(
          tester.getTopLeft(beds).dy,
          greaterThan(tester.getTopLeft(booking).dy),
        );
        expect(
          tester.getTopLeft(beds).dy,
          lessThan(
            tester.getTopLeft(find.text('Washing machine: Not recorded')).dy,
          ),
        );
        expect(find.text('Check-in: 14:00 - 20:00 (assumed)'), findsOneWidget);
      }
    });
  }
}
