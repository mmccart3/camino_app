import 'dart:collection';

import 'models.dart';

/// Walk linked stages in breadth-first order, primary before alternative.
/// Parallel routes stay together and shared destinations appear only once.
/// IDs only break ties between starts or disconnected/cyclic components.
List<Stage> orderStages(Iterable<Stage> stages) {
  final sorted = stages.toList()..sort((a, b) => a.id.compareTo(b.id));
  final byId = {for (final stage in sorted) stage.id: stage};
  final incoming = <int>{
    for (final stage in sorted)
      for (final id in [stage.nextStageId, stage.alternativeNextStageId])
        if (id != null && id != 0 && byId.containsKey(id)) id,
  };
  final queue = Queue<Stage>();
  final scheduled = <int>{};
  final result = <Stage>[];
  void enqueue(Stage stage) {
    if (scheduled.add(stage.id)) queue.add(stage);
  }

  void drain() {
    while (queue.isNotEmpty) {
      final stage = queue.removeFirst();
      result.add(stage);
      for (final id in [stage.nextStageId, stage.alternativeNextStageId]) {
        final next = id == null || id == 0 ? null : byId[id];
        if (next != null) enqueue(next);
      }
    }
  }

  for (final stage in sorted) {
    if (!incoming.contains(stage.id)) enqueue(stage);
  }
  drain();
  // Keep malformed or disconnected cycles visible without looping forever.
  for (final stage in sorted) {
    if (!scheduled.contains(stage.id)) {
      enqueue(stage);
      drain();
    }
  }
  return result;
}
