import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/contact_number.dart';
import 'package:camino_app/services/safe_links.dart';
import 'package:camino_app/ui/contact_links.dart';
import 'package:camino_app/services/map_links.dart';
import 'package:latlong2/latlong.dart' show LatLng;

void main() {
  test('website validation accepts HTTP and HTTPS only', () {
    for (final url in [
      'http://example.com/a?x=1&y=2',
      'https://example.com/',
    ]) {
      expect(SafeLinks.isWebsite(url), isTrue);
    }
    for (final url in [
      '',
      'no website available',
      'javascript:alert(1)',
      'file:///tmp/a',
      'https://user:pass@example.com',
      'https://example.com/ bad',
    ]) {
      expect(SafeLinks.isWebsite(url), isFalse);
    }
    expect(SafeLinks.isSafe('http://example.com'), isFalse);
  });
  for (final private in [false, true]) {
    testWidgets('website works without contacts for private=$private', (
      tester,
    ) async {
      for (final url in [
        'http://example.com/path?x=1&y=2',
        'https://example.com/',
        'no website available',
      ]) {
        final row = <String, Object?>{
          'ID': 1,
          'locationID': 1,
          'albergueName': 'Test',
          'privateAccommName': 'Test',
          'albergueWebsiteURL': url,
          'privateAccommWebsiteURL': url,
        };
        final Accommodation place = private
            ? PrivateAccommodation.fromRow(row)
            : Albergue.fromRow(row);
        final opened = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContactLinks(
                place: place,
                openWebsite: (value) async {
                  opened.add(value);
                },
              ),
            ),
          ),
        );
        final button = find.text('Visit accommodation website');
        if (url == 'no website available') {
          expect(button, findsNothing);
        } else {
          await tester.tap(button);
          await tester.pump();
          expect(opened, [url]);
        }
      }
    });
  }

  test('Apple walking URL uses stored coordinates and current origin', () {
    final url = MapLinks.appleWalkingDirections(
      const LatLng(43.16345, -1.23593),
    )!;
    final uri = Uri.parse(url);
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters, {'daddr': '43.16345,-1.23593', 'dirflg': 'w'});
    expect(SafeLinks.isSafe(url), isTrue);
    expect(MapLinks.appleWalkingDirections(null), isNull);
    expect(MapLinks.appleWalkingDirections(const LatLng(0, 0)), isNull);
    expect(MapLinks.appleWalkingDirections(LatLng(double.nan, 1)), isNull);
  });
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    for (final private in [false, true]) {
      testWidgets(
        'Apple link visibility and target: $platform private=$private',
        (tester) async {
          final row = <String, Object?>{
            'ID': 1,
            'locationID': 1,
            'albergueName': 'Test',
            'privateAccommName': 'Test',
            'gps_lat': 43.16345,
            'gps_lng': -1.23593,
          };
          final Accommodation place = private
              ? PrivateAccommodation.fromRow(row)
              : Albergue.fromRow(row);
          final urls = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: ContactLinks(
                  place: place,
                  open: (url) async {
                    urls.add(url);
                  },
                ),
              ),
            ),
          );
          expect(find.text('Walk here with Google Maps'), findsOneWidget);
          final apple = find.text('Walk here with Apple Maps');
          if (platform == TargetPlatform.iOS) {
            expect(apple, findsOneWidget);
            await tester.tap(apple);
            await tester.pump();
            expect(Uri.parse(urls.single).host, 'maps.apple.com');
            expect(Uri.parse(urls.single).queryParameters, {
              'daddr': '43.16345,-1.23593',
              'dirflg': 'w',
            });
          } else {
            expect(apple, findsNothing);
          }
        },
      );
    }
  }

  test(
    'walking URLs preserve destination, request walking and let Maps choose origin',
    () {
      final uri = Uri.parse(
        MapLinks.walkingDirections(const LatLng(43.16345, -1.23593))!,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters, {
        'api': '1',
        'destination': '43.16345,-1.23593',
        'travelmode': 'walking',
        'dir_action': 'navigate',
      });
      expect(MapLinks.walkingDirections(null), isNull);
      expect(MapLinks.walkingDirections(const LatLng(0, 0)), isNull);
      expect(MapLinks.walkingDirections(LatLng(double.nan, 1)), isNull);
    },
  );
  for (final private in [false, true]) {
    testWidgets(
      '${private ? 'private accommodation' : 'albergue'} opens walking directions even without phone data',
      (tester) async {
        final row = <String, Object?>{
          'ID': 1,
          'locationID': 1,
          'albergueName': 'Test',
          'privateAccommName': 'Test',
          'gps_lat': 43.16345,
          'gps_lng': -1.23593,
        };
        final Accommodation place = private
            ? PrivateAccommodation.fromRow(row)
            : Albergue.fromRow(row);
        final urls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContactLinks(
                place: place,
                open: (url) async {
                  urls.add(url);
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Walk here with Google Maps'));
        await tester.pump();
        expect(
          Uri.parse(urls.single).queryParameters['destination'],
          '43.16345,-1.23593',
        );
        expect(Uri.parse(urls.single).queryParameters['travelmode'], 'walking');
        expect(find.textContaining('Call +'), findsNothing);
      },
    );
  }
  test(
    'formats stored country codes and phone numbers without dial commands',
    () {
      expect(ContactNumber.phone(948760000, 34)?.international, '+34948760000');
      expect(
        ContactNumber.phone('+33 6 61 96 04 76', 34)?.international,
        '+33661960476',
      );
      expect(
        ContactNumber.phone('0034 948-760-000', null)?.international,
        '+34948760000',
      );
      for (final invalid in [
        null,
        0,
        'NULL',
        'not available',
        '*123#',
        '123;456',
        '123?body=x',
        double.nan,
      ]) {
        expect(ContactNumber.phone(invalid, 34), isNull);
      }
      expect(ContactNumber.phone(948760000, null), isNull);
      expect(
        ContactNumber.internationalNumber('+34 (600) 123-456')?.whatsAppUrl,
        'https://wa.me/34600123456',
      );
      expect(ContactNumber.internationalNumber(0), isNull);
    },
  );
  test('ordinary phone numbers never imply WhatsApp availability', () {
    final place = PrivateAccommodation.fromRow({
      'ID': 1,
      'locationID': 1,
      'privateAccommName': 'Test',
      'tel1CountryCode': 34,
      'tel1PhoneNumber': 948760000,
      'tel2CountryCode': 34,
      'tel2PhoneNumber': 948760000,
    });
    expect(place.phoneNumbers.length, 1);
    expect(place.whatsAppNumber, isNull);
  });
  test(
    'phone launcher rejects unvalidated targets before any platform call',
    () async {
      for (final invalid in [
        'tel:+34948760000',
        '+34948760000;123',
        'javascript:alert(1)',
        '0',
      ]) {
        await expectLater(SafeLinks.call(invalid), throwsArgumentError);
      }
    },
  );
  for (final private in [false, true]) {
    testWidgets(
      '${private ? 'private accommodation' : 'albergue'} contact links open correct targets',
      (tester) async {
        final row = <String, Object?>{
          'ID': 1,
          'locationID': 1,
          'albergueName': 'Test',
          'privateAccommName': 'Test',
          'tel1CountryCode': 34,
          'tel1PhoneNumber': 948760000,
          'tel2CountryCode': 34,
          'tel2PhoneNumber': 600123456,
          'whatsAppNumber': 34600123456,
        };
        final Accommodation place = private
            ? PrivateAccommodation.fromRow(row)
            : Albergue.fromRow(row);
        final calls = <String>[], urls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContactLinks(
                place: place,
                call: (number) async {
                  calls.add(number);
                },
                open: (url) async {
                  urls.add(url);
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Call +34948760000'));
        await tester.pump();
        await tester.tap(find.text('Call +34600123456'));
        await tester.pump();
        await tester.tap(find.text('WhatsApp +34600123456'));
        await tester.pump();
        expect(calls, ['+34948760000', '+34600123456']);
        expect(urls, ['https://wa.me/34600123456']);
      },
    );
  }
  testWidgets('missing contacts are hidden and launcher errors are displayed', (
    tester,
  ) async {
    final empty = Albergue.fromRow({
      'ID': 1,
      'locationID': 1,
      'albergueName': 'Test',
      'tel1PhoneNumber': 0,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactLinks(place: empty)),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    final place = Albergue.fromRow({
      ...empty.source,
      'tel1CountryCode': 34,
      'tel1PhoneNumber': 948760000,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactLinks(
            place: place,
            call: (_) async {
              throw StateError('No calling app');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Call +34948760000'));
    await tester.pump();
    expect(find.textContaining('No calling app'), findsOneWidget);
  });
}
