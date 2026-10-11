import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/walking_day.dart';
import '../services/walking_time.dart';

/// Browses a single forward route; branch choices retain the preceding legs.
class WalkingStopPicker extends StatefulWidget {
  final WalkingDayPlanner planner;
  final CaminoRepository repository;
  final int start;
  final double pace;
  const WalkingStopPicker({
    super.key,
    required this.planner,
    required this.repository,
    required this.start,
    required this.pace,
  });
  @override
  State<WalkingStopPicker> createState() => _WalkingStopPickerState();
}

class _WalkingStopPickerState extends State<WalkingStopPicker> {
  final choices = <int, int>{};
  final counts = <int, Future<int>>{};
  late final stages = widget.repository.stages();
  Future<int> count(int id) => counts.putIfAbsent(id, () async {
    final hostels = await widget.repository.albergues(id);
    final rooms = await widget.repository.privateAccommodation(id);
    return hostels.length + rooms.length;
  });

  @override
  Widget build(BuildContext context) {
    final planner = widget.planner;
    final chain = <int>[];
    final rows = <({Location place, List<int> paths, List<DayLeg> branches})>[];
    final visited = <int>{};
    var current = widget.start;
    while (visited.add(current)) {
      final place = planner.locations[current];
      if (place == null) break;
      final branches = planner.legs.values
          .where(
            (leg) =>
                leg.path.originLocationId == current &&
                !visited.contains(leg.path.destinationLocationId),
          )
          .where((leg) {
            try {
              planner.calculate([
                if (chain.isNotEmpty) chain.last,
                leg.path.id,
              ], widget.pace);
              return true;
            } catch (_) {
              return false;
            }
          })
          .toList();
      rows.add((place: place, paths: List.of(chain), branches: branches));
      if (branches.isEmpty) break;
      final selected = branches.firstWhere(
        (leg) => leg.path.id == choices[current],
        orElse: () => branches.first,
      );
      chain.add(selected.path.id);
      current = selected.path.destinationLocationId;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your overnight stop'),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Distances and walking times from ${planner.locations[widget.start]?.name}. Choose Stay here, then review and save your day.',
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final day = row.paths.isEmpty
              ? null
              : planner.calculate(row.paths, widget.pace);
          final services = [
            ('hasBarCafe', 'Café', Icons.local_cafe_outlined),
            ('hasPharmacy', 'Pharmacy', Icons.local_pharmacy_outlined),
            ('hasGroceryStore', 'Groceries', Icons.shopping_basket_outlined),
          ].where((s) => row.place.facility(s.$1) == true);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.place.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    day == null
                        ? 'Starting place'
                        : '${(day.metres / 1000).toStringAsFixed(1)} km | ${WalkingTime.format(day.walkingTime)} walking',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final service in services)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(service.$3, size: 28),
                            Text(service.$2),
                          ],
                        ),
                    ],
                  ),
                  FutureBuilder<int>(
                    future: count(row.place.id),
                    builder: (context, snapshot) => Text(
                      snapshot.hasError
                          ? 'Accommodation count unavailable'
                          : !snapshot.hasData
                          ? 'Loading accommodation…'
                          : snapshot.data == 0
                          ? 'No accommodation listed here'
                          : '${snapshot.data} places to stay listed',
                    ),
                  ),
                  if (day != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bed_outlined),
                        label: const Text('Stay here'),
                        onPressed: () => Navigator.pop(context, row.paths),
                      ),
                    ),
                  if (row.branches.length > 1) ...[
                    const Divider(),
                    const Text('Route from here'),
                    FutureBuilder<List<Stage>>(
                      future: stages,
                      builder: (context, snapshot) => Column(
                        children: [
                          for (final branch in row.branches)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Via ${planner.locations[branch.path.destinationLocationId]?.name ?? 'next place'}',
                              ),
                              subtitle: Text(
                                snapshot.data
                                        ?.where(
                                          (s) => s.id == branch.path.stageId,
                                        )
                                        .map((s) => 'Stage ${s.displayNumber}')
                                        .join() ??
                                    '',
                              ),
                              leading: Icon(
                                (choices[row.place.id] ??
                                            row.branches.first.path.id) ==
                                        branch.path.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                              ),
                              selected:
                                  (choices[row.place.id] ??
                                      row.branches.first.path.id) ==
                                  branch.path.id,
                              onTap: () => setState(() {
                                choices[row.place.id] = branch.path.id;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
