import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/walking_location_order.dart';

Location place(int id, String name) =>
    Location.fromRow({'ID': id, 'locationName': name});
Path path(int id, int start, int end) => Path.fromRow({
  'pathID': id,
  'stageID': 1,
  'originLoc': start,
  'destinationLoc': end,
});
void main() {
  test('destinations follow paths rather than alphabet or location IDs', () {
    final result = orderWalkingLocations(
      [place(9, 'Alpha'), place(1, 'Middle'), place(8, 'Zulu')],
      [path(1, 8, 1), path(2, 1, 9)],
    );
    expect(result.map((p) => p.id), [8, 1, 9]);
  });
  test(
    'both alternative branches precede shared destination, without duplicates',
    () {
      final result = orderWalkingLocations(
        [for (var i = 1; i <= 6; i++) place(i, 'Place $i')],
        [
          path(1, 1, 2),
          path(2, 2, 3),
          path(3, 3, 6),
          path(4, 1, 4),
          path(5, 4, 5),
          path(6, 5, 6),
          path(7, 3, 6),
        ],
      );
      expect(result.map((p) => p.id), [1, 2, 3, 4, 5, 6]);
    },
  );
  test('missing endpoints, disconnected locations and cycles remain safe', () {
    final result = orderWalkingLocations(
      [place(1, 'One'), place(2, 'Two'), place(3, 'Three')],
      [path(1, 1, 2), path(2, 2, 1), path(3, 9, 1), path(4, 2, 2)],
    );
    expect(result.map((p) => p.id).toSet(), {1, 2, 3});
    expect(result.length, 3);
  });
}
