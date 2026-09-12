import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/stage_order.dart';
import 'package:flutter_test/flutter_test.dart';

Stage stage(int id, {int? next, int? alternate}) => Stage.fromRow({
  'ID': id,
  'stageStartLocationID': 1,
  'stageFinishLocationID': 2,
  'nextStage': next,
  'altNextStage': alternate,
});

void main() {
  test('follows links with alternatives before continuing parallel routes', () {
    final stages = [
      stage(1, next: 8, alternate: 3),
      stage(3, next: 4),
      stage(4, next: 2),
      stage(2),
      stage(8, next: 9),
      stage(9, next: 2),
    ];
    expect(orderStages(stages.reversed).map((s) => s.id), [1, 8, 3, 9, 4, 2]);
  });
  test('multiple starts converge without duplicating their destination', () {
    expect(
      orderStages([
        stage(1, next: 2),
        stage(2),
        stage(43, next: 2),
      ]).map((s) => s.id),
      [1, 43, 2],
    );
  });
  test('missing targets, zero, repeated links and cycles remain safe', () {
    expect(
      orderStages([
        stage(1, next: 99, alternate: 0),
        stage(2, next: 3, alternate: 3),
        stage(3, next: 2),
        stage(4, next: 4),
      ]).map((s) => s.id),
      [1, 2, 3, 4],
    );
    expect(orderStages([]), isEmpty);
  });
}
