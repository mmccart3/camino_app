import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/settings_service.dart';
import '../services/recent_walk.dart';
import '../services/navigation_session.dart';
import '../services/camino_plan_store.dart';
import '../services/walking_day_store.dart';
import '../services/walking_day.dart';
import 'home_screen.dart' show nextPlannedDay;
import 'map_screen.dart';
import 'widgets.dart';
import 'feature_navigation.dart';

class CurrentStageMap extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  const CurrentStageMap({
    super.key,
    required this.repository,
    required this.settings,
  });
  @override
  State<CurrentStageMap> createState() => _CurrentStageMapState();
}

class _CurrentStageMapState extends State<CurrentStageMap> {
  late Future<Stage?> future = load();
  int? lastTab;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = context
        .dependOnInheritedWidgetOfExactType<FeatureNavigation>()
        ?.selected;
    if (tab == 2 && lastTab != null && lastTab != 2) future = load();
    lastTab = tab;
  }

  Future<Stage?> load() async {
    final stages = await widget.repository.stages();
    final session = NavigationSession.instance;
    (int, bool)? recent;
    try {
      recent = await RecentWalk.load();
    } catch (_) {
      /* Fall back to a planned or first stage. */
    }
    final id = session.active ? session.stageId : recent?.$1;
    var selected = stages.where((s) => s.id == id).firstOrNull;
    try {
      final store = CaminoPlanStore.instance;
      final days = <ItineraryDay>[];
      for (final plan in await store.plans()) {
        days.addAll(await store.days(plan.id));
      }
      final now = DateTime.now();
      bool today(SavedWalkingDay d) =>
          DateUtils.isSameDay(DateTime.tryParse(d.date ?? ''), now);
      final upcoming = nextPlannedDay(days, now);
      final planned = upcoming != null && today(upcoming.route)
          ? upcoming.route
          : (await WalkingDayStore().load()).where(today).firstOrNull;
      if (planned != null) {
        final planner = await WalkingDayPlanner.load(widget.repository);
        final routeStages = planner
            .calculate(planned.pathIds, planned.pace)
            .legs
            .map((l) => l.stage)
            .whereType<Stage>();
        selected =
            routeStages.where((s) => s.id == selected?.id).firstOrNull ??
            routeStages.firstOrNull;
      }
    } catch (_) {
      /* A damaged personal plan must not prevent map browsing. */
    }
    return selected ?? stages.firstOrNull;
  }

  @override
  Widget build(BuildContext context) => DataView(
    future: future,
    retry: () => future = load(),
    builder: (stage) => stage == null
        ? const Scaffold(
            body: Center(child: Text('No stages in this database.')),
          )
        : MapScreen(
            key: ValueKey(stage.id),
            repository: widget.repository,
            settings: widget.settings,
            stage: stage,
          ),
  );
}
