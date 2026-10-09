import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../services/settings_service.dart';
import '../services/camino_plan_store.dart';
import '../services/recent_walk.dart';
import '../services/navigation_session.dart';
import 'app_title.dart';
import 'app_logo.dart';
import 'screens.dart' show StageListScreen, StageDetailScreen;
import 'map_screen.dart';
import 'settings_screen.dart';
import 'camino_plan_screen.dart';
import 'walking_day_screen.dart';
import 'ahead_screen.dart';
import 'elevation_screen.dart';
import 'navigation_summary.dart' show navigationTime;

/// Dated days from today onwards first; otherwise the first undated day.
ItineraryDay? nextPlannedDay(List<ItineraryDay> days, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final dated =
      days.where((d) {
        final date = DateTime.tryParse(d.route.date ?? '');
        return date != null && !date.isBefore(today);
      }).toList()..sort((a, b) {
        final comparison = a.route.date!.compareTo(b.route.date!);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
  return dated.firstOrNull ??
      days.where((d) => d.route.date == null).firstOrNull;
}

class HomeScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  const HomeScreen({
    super.key,
    required this.repository,
    required this.settings,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stage? recent;
  bool recentMap = false, loading = true;
  String? planError;
  List<CaminoPlan> plans = [];
  ItineraryDay? next;
  int revision = 0;
  final store = CaminoPlanStore.instance;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++revision;
    Stage? stage;
    var map = false;
    try {
      final saved = await RecentWalk.load();
      final session = NavigationSession.instance;
      final id = session.active ? session.stageId : saved?.$1;
      if (id != null) stage = await widget.repository.stage(id);
      map = session.active || (saved?.$2 ?? false);
    } catch (_) {
      /* Browsing remains available if the remembered stage is missing. */
    }
    List<CaminoPlan> loaded = [];
    ItineraryDay? upcoming;
    String? error;
    try {
      loaded = await store.plans();
      final days = <ItineraryDay>[];
      for (final plan in loaded) {
        days.addAll(await store.days(plan.id));
      }
      upcoming = nextPlannedDay(days, DateTime.now());
    } catch (_) {
      error = 'Your saved plans could not be loaded.';
    }
    if (!mounted || token != revision) return;
    setState(() {
      recent = stage;
      recentMap = map;
      plans = loaded;
      next = upcoming;
      planError = error;
      loading = false;
    });
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await load();
  }

  void openPlans() => open(
    CaminoPlansScreen(repository: widget.repository, settings: widget.settings),
  );
  @override
  Widget build(BuildContext context) {
    final day = next;
    final plan = day == null
        ? null
        : plans.where((p) => p.id == day.planId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const AppTitle(compact: true),
        centerTitle: true,
        backgroundColor: caminoBlue,
        foregroundColor: caminoYellow,
        actions: [
          IconButton(
            tooltip: 'Settings',
            iconSize: 30,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => open(SettingsScreen(settings: widget.settings)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppLogo(size: 112),
                  const SizedBox(height: 16),
                  Text(
                    'One step at a time.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (recent != null) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                      ),
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Continue my walk'),
                      onPressed: () => open(
                        recentMap
                            ? MapScreen(
                                repository: widget.repository,
                                settings: widget.settings,
                                stage: recent!,
                              )
                            : StageDetailScreen(
                                repository: widget.repository,
                                settings: widget.settings,
                                stage: recent!,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      child: Text(recent!.name, textAlign: TextAlign.center),
                    ),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(18),
                    ),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('My Camino plan'),
                    onPressed: openPlans,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(18),
                    ),
                    icon: const Icon(Icons.route),
                    label: const Text('Browse stages'),
                    onPressed: () => open(
                      StageListScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (planError != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(planError!),
                            TextButton(
                              onPressed: load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (day != null && plan != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.route.date == null
                                  ? 'Next undated day'
                                  : 'Next planned day',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(plan.name),
                            Text(day.route.date ?? 'Date not set'),
                            const SizedBox(height: 8),
                            Text(
                              '${day.startName} → ${day.endName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              day.hasEstimate
                                  ? '${(day.metres! / 1000).toStringAsFixed(1)} km / ${navigationTime(Duration(seconds: day.seconds!))}'
                                  : 'Distance and walking time not yet estimated',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              day.stay == null
                                  ? 'Accommodation not chosen'
                                  : '${day.stay!.name} (${day.stay!.status})',
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open this plan'),
                              onPressed: () => open(
                                CaminoPlanScreen(
                                  repository: widget.repository,
                                  settings: widget.settings,
                                  plan: plan,
                                  store: store,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plans.isEmpty
                                  ? 'Your Camino, at your pace'
                                  : 'Your saved plans',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plans.isEmpty
                                  ? 'Plan your walking days and keep your chosen stays together.'
                                  : 'No upcoming or undated days. Open a plan to review or add days.',
                            ),
                            TextButton(
                              onPressed: openPlans,
                              child: Text(
                                plans.isEmpty
                                    ? 'Create my plan'
                                    : 'Manage my plans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_note),
                    label: const Text('My walking day'),
                    onPressed: () => open(
                      WalkingDayScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Ahead of me'),
                    onPressed: () => open(
                      AheadStagePicker(
                        repository: widget.repository,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('Trail elevation'),
                    onPressed: () =>
                        open(ElevationScreen(repository: widget.repository)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
