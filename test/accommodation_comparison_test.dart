import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/ui/accommodation_comparison.dart';

void main() {
  test('facility filters require positive evidence and combine', () {
    final unknown = Albergue.fromRow({'ID': 1, 'locationID': 1});
    final kitchen = Albergue.fromRow({
      'ID': 2,
      'locationID': 1,
      'kitchenFacilitiesAvailable': 1,
      'communalMealAvailable': 0,
    });
    expect(matchesAccommodation(unknown), isTrue);
    expect(matchesAccommodation(unknown, kitchen: true), isFalse);
    expect(matchesAccommodation(kitchen, kitchen: true), isTrue);
    expect(matchesAccommodation(kitchen, kitchen: true, meal: true), isFalse);
  });
  test('private rooms require confirmation regardless of room prices', () {
    final dorm = Albergue.fromRow({
      'ID': 1,
      'locationID': 1,
      'onedPersonRateMin': 15,
    });
    final room = Albergue.fromRow({
      'ID': 2,
      'locationID': 1,
      'twoPersonRateMin': 45,
    });
    expect(matchesAccommodation(dorm, privateRoom: true), isFalse);
    expect(matchesAccommodation(room, privateRoom: true), isFalse);
    for (final flag in [null, 0, 1]) {
      final hostel = Albergue.fromRow({
        'ID': 4,
        'locationID': 1,
        'twoPersonRateMin': 45,
        'privateRoomsAvailable': flag,
      });
      expect(matchesAccommodation(hostel, privateRoom: true), flag == 1);
    }
    expect(
      matchesAccommodation(
        Albergue.fromRow({
          'ID': 5,
          'locationID': 1,
          'privateRoomsAvailable': 1,
        }),
        privateRoom: true,
      ),
      isTrue,
    );
    expect(
      matchesAccommodation(
        PrivateAccommodation.fromRow({'ID': 3, 'locationID': 1}),
        privateRoom: true,
      ),
      isTrue,
    );
  });
}
