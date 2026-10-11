import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/data/map_accommodation.dart';
import 'package:camino_app/data/models.dart';

void main() {
  PrivateAccommodation place(int id, String name, {double lat = 42.99066}) =>
      PrivateAccommodation.fromRow({
        'ID': id,
        'privateAccommName': name,
        'locationID': id,
        'gps_lat': lat,
        'gps_lng': -1.33486,
      });

  test(
    'duplicate imports count once and retain the original detail record',
    () {
      final original = place(5962, 'Hostal Burguete');
      final result = uniqueMapAccommodation([
        original,
        place(7348, 'Hostal Burguete'),
        place(7388, ' Hostal  Burguete '),
      ]);
      expect(result, [original]);
    },
  );
  test(
    'distinct colocated properties and same names elsewhere remain visible',
    () {
      final records = [
        place(1, 'Hostal Burguete'),
        place(2, 'Another hotel'),
        place(3, 'Hostal Burguete', lat: 43),
        Albergue.fromRow({
          'ID': 1,
          'albergueName': 'Hostal Burguete',
          'locationID': 1,
          'gps_lat': 42.99066,
          'gps_lng': -1.33486,
        }),
      ];
      expect(uniqueMapAccommodation(records), records);
    },
  );
}
