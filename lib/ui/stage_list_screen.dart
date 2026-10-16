import 'app_title.dart';
import 'settings_screen.dart';
import '../services/place_search.dart';
import '../services/camino_plan_store.dart';
import '../services/walking_day_store.dart';
import 'feature_navigation.dart';
import 'map_screen.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../data/route_assembler.dart';
import '../services/settings_service.dart';
import '../services/recent_walk.dart';
import '../services/walking_time.dart';
import '../services/stage_walking_time.dart';
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
  late var future = widget.repository.stages();
  final routes = <int, Future<StageRoute>>{};
  int? recent;
  final search = TextEditingController();
  String query = '', filter = 'All';
  Set<int> planned = {};
  final searchNames = <int, String>{};
  String? planError;
  int? lastTab;
  @override
  void dispose() {
    search.dispose();
    widget.settings.removeListener(refreshPace);
    super.dispose();
  }

  void refreshPace() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = context
        .dependOnInheritedWidgetOfExactType<FeatureNavigation>()
        ?.selected;
    if (lastTab != null && tab != lastTab && tab == (widget.mapMode ? 2 : 1)) {
      restore();
    }
    lastTab = tab;
  }

  Future<void> loadSearchNames() async {
    final stages = await future;
    final names = <int, String>{};
    for (final stage in stages) {
      final locations = await widget.repository.locations(stage.id);
      names[stage.id] = locations.map((l) => l.name).join(' ');
    }
    if (mounted) setState(() => searchNames.addAll(names));
  }

  bool routeChoice(Stage stage, List<Stage> stages) =>
      RegExp(r'[a-z]$', caseSensitive: false).hasMatch(stage.displayNumber) ||
      stages.any(
        (p) =>
            p.alternativeNextStageId != null &&
            (p.nextStageId == stage.id || p.alternativeNextStageId == stage.id),
      );

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(refreshPace);
    restore();
    loadSearchNames().catchError((Object _) {});
  }

  Future<void> restore() async {
    try {
      final pathIds = <int>{};
      final store = CaminoPlanStore.instance;
      for (final plan in await store.plans()) {
        for (final day in await store.days(plan.id)) {
          pathIds.addAll(day.route.pathIds);
        }
      }
      for (final day in await WalkingDayStore().load()) {
        pathIds.addAll(day.pathIds);
      }
      final ids = <int>{};
      for (final stage in await future) {
        if ((await widget.repository.paths(
          stage.id,
        )).any((p) => pathIds.contains(p.id))) {
          ids.add(stage.id);
        }
      }
      if (mounted) {
        setState(() {
          planned = ids;
          planError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => planError = 'Saved plans could not be loaded.');
      }
    }

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
        settings: RouteSettings(
          name: widget.mapMode ? 'map/${stage.id}' : 'stage/${stage.id}',
        ),
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
      title: Text(widget.mapMode ? 'Choose a stage map' : 'Explore'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: DataView(
        future: future,
        retry: () => future = widget.repository.stages(),
        builder: (stages) {
          if (stages.isEmpty) {
            return const Center(child: Text('No stages in this database.'));
          }
          final visible = stages
              .where(
                (stage) =>
                    (filter != 'Planned' || planned.contains(stage.id)) &&
                    (filter != 'Route choices' || routeChoice(stage, stages)) &&
                    matchesPlaceName(
                      'Stage ${stage.displayNumber} ${stage.name} ${searchNames[stage.id] ?? ""}',
                      query,
                    ),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    labelText: 'Search a town or stage',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              search.clear();
                              setState(() => query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final name in ['All', 'Planned', 'Route choices'])
                      ChoiceChip(
                        label: Text(name),
                        selected: filter == name,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        checkmarkColor: caminoYellow,
                        labelStyle: TextStyle(
                          color: filter == name
                              ? caminoYellow
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onSelected: (_) => setState(() => filter = name),
                      ),
                  ],
                ),
              ),
              if (filter == 'Planned' && planError != null)
                TextButton(onPressed: restore, child: Text('$planError Retry')),
              if (visible.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 40),
                        const Text('No matching stages'),
                        TextButton(
                          onPressed: () {
                            search.clear();
                            setState(() {
                              query = '';
                              filter = 'All';
                            });
                          },
                          child: const Text('Show all stages'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Estimates use your walking speed.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SettingsScreen(
                                        settings: widget.settings,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                      final stage = visible[index - 1];
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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Stage ${stage.displayNumber}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    if (routeChoice(stage, stages))
                                      const Chip(
                                        avatar: Icon(Icons.alt_route, size: 18),
                                        label: Text('Route choice'),
                                      ),
                                    if (stage.id == recent)
                                      const Chip(label: Text('Selected stage')),
                                    if (planned.contains(stage.id))
                                      const Chip(label: Text('Planned')),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  stage.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<StageRoute>(
                                  future: routes.putIfAbsent(
                                    stage.id,
                                    () => widget.repository.route(stage),
                                  ),
                                  builder: (context, snapshot) {
                                    final route = snapshot.data;
                                    final time = route == null
                                        ? null
                                        : routeWalkingTime(
                                            route,
                                            widget.settings.paceKmh,
                                          );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 8,
                                          children: [
                                            Text(
                                              stage.distanceMeters == null
                                                  ? 'Distance unavailable'
                                                  : '${(stage.distanceMeters! / 1000).toStringAsFixed(1)} km',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
