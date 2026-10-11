import 'map_screen.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../data/route_assembler.dart';
import '../services/settings_service.dart';
import '../services/recent_walk.dart';
import '../services/walking_time.dart';
import 'screens.dart' show StageDetailScreen;
import 'widgets.dart';

class StageListScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final bool mapMode;
  const StageListScreen({
    super.key,
    this.mapMode = false,
    required this.repository,
    required this.settings,
  });
  @override
  State<StageListScreen> createState() => _StageListScreenState();
}

class _StageListScreenState extends State<StageListScreen> {
  late final future = widget.repository.stages();
  final routes = <int, Future<StageRoute>>{};
  int? recent;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final saved = await RecentWalk.load();
      if (mounted) setState(() => recent = saved?.$1);
    } catch (_) {
      /* Stage browsing remains available. */
    }
  }

  Future<void> open(Stage stage) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.mapMode
            ? MapScreen(
                repository: widget.repository,
                settings: widget.settings,
                stage: stage,
              )
            : StageDetailScreen(
                repository: widget.repository,
                settings: widget.settings,
                stage: stage,
              ),
      ),
    );
    await restore();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.mapMode ? 'Choose a stage map' : 'Stages'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: DataView(
        future: future,
        builder: (stages) {
          if (stages.isEmpty) {
            return const Center(child: Text('No stages in this database.'));
          }
          final last = stages.where((s) => s.id == recent).firstOrNull;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (last != null) ...[
                      FilledButton.icon(
                        onPressed: () => open(last),
                        icon: const Icon(Icons.directions_walk),
                        label: Text('Continue here: ${last.name}'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Walking estimates use your saved flat-ground pace.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              final stage = stages[index - 1];
              final alternatives = <int>{};
              for (final parent in stages) {
                if (parent.alternativeNextStageId != null &&
                    (parent.nextStageId == stage.id ||
                        parent.alternativeNextStageId == stage.id)) {
                  alternatives.addAll([
                    if (parent.nextStageId != null) parent.nextStageId!,
                    parent.alternativeNextStageId!,
                  ]);
                }
              }
              alternatives.remove(stage.id);
              final peers = stages
                  .where((s) => alternatives.contains(s.id))
                  .toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: stage.id == recent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: stage.id == recent ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => open(stage),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage ${stage.displayNumber}${stage.id == recent ? ' / Last opened' : ''}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stage.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (peers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Route choice / Alternative: ${peers.map((s) => s.name).join(' / ')}',
                            ),
                          ),
                        const SizedBox(height: 12),
                        FutureBuilder<StageRoute>(
                          future: routes.putIfAbsent(
                            stage.id,
                            () => widget.repository.route(stage),
                          ),
                          builder: (context, snapshot) {
                            final route = snapshot.data;
                            Duration? time;
                            if (route != null && route.canGuide) {
                              final weights = route.points
                                  .skip(1)
                                  .map((p) => p.weightedDistance)
                                  .toList();
                              if (weights.isNotEmpty &&
                                  weights.every(
                                    (w) => w != null && w.isFinite && w >= 0,
                                  )) {
                                time = WalkingTime.estimate(
                                  weights.fold<double>(0, (sum, w) => sum + w!),
                                  widget.settings.paceKmh,
                                );
                              }
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (route != null &&
                                    route.locations.any(
                                      (l) => l.id == stage.startLocationId,
                                    )) ...[
                                  Text(
                                    'From ${route.locations.firstWhere((l) => l.id == stage.startLocationId).name}',
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      stage.distanceMeters == null
                                          ? 'Distance unavailable'
                                          : '${(stage.distanceMeters! / 1000).toStringAsFixed(1)} km',
                                    ),
                                    Text(
                                      time == null
                                          ? (snapshot.connectionState !=
                                                    ConnectionState.done
                                                ? 'Loading walking time…'
                                                : 'Walking time unavailable')
                                          : '${WalkingTime.format(time)} walking',
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text('View stage →'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
