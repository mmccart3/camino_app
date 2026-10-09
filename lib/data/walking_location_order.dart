import 'models.dart';

/// Order destinations by forward paths, with stage/path order breaking ties.
/// Alternative branches precede their shared destination, shown only once.
/// Disconnected places remain selectable; malformed cycles cannot hang the UI.
List<Location> orderWalkingLocations(
  Iterable<Location> locations,
  Iterable<Path> paths,
) {
  final byId = {for (final place in locations) place.id: place};
  final priority = <int>{};
  final outgoing = <int, Set<int>>{};
  final incoming = {for (final id in byId.keys) id: 0};
  for (final path in paths) {
    final start = path.originLocationId;
    final end = path.destinationLocationId;
    if (byId.containsKey(start)) priority.add(start);
    if (byId.containsKey(end)) priority.add(end);
    if (start == end || !byId.containsKey(start) || !byId.containsKey(end)) {
      continue;
    }
    if (outgoing.putIfAbsent(start, () => <int>{}).add(end)) {
      incoming[end] = incoming[end]! + 1;
    }
  }
  priority.addAll(byId.keys);
  final remaining = priority.toSet();
  final result = <Location>[];
  while (remaining.isNotEmpty) {
    // The first remaining place is a deterministic fallback for a cycle.
    final id = remaining.firstWhere(
      (id) => incoming[id] == 0,
      orElse: () => remaining.first,
    );
    remaining.remove(id);
    result.add(byId[id]!);
    for (final next in outgoing[id] ?? <int>{}) {
      incoming[next] = incoming[next]! - 1;
    }
  }
  return result;
}
