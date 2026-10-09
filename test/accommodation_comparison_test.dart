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
  test('dorm price alone is not evidence of private rooms', () {
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
    expect(matchesAccommodation(room, privateRoom: true), isTrue);
    expect(
      matchesAccommodation(
        PrivateAccommodation.fromRow({'ID': 3, 'locationID': 1}),
        privateRoom: true,
      ),
      isTrue,
    );
  });
}
