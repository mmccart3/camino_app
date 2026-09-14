import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:camino_app/ui/stage_directions.dart';

void main() {
  const start = LatLng(42, -2);
  const later = LatLng(42.1, -2);
  test('chooses stage start when closer or tied', () {
    expect(stageEntryPoint(start, start, [start, later]), start);
    expect(stageEntryPoint(start, start, []), start);
  });
  test('chooses closer track point and handles absent start', () {
    expect(stageEntryPoint(later, start, [start, later]), later);
    expect(stageEntryPoint(later, null, [later]), later);
    expect(stageEntryPoint(later, null, []), isNull);
  });
}
