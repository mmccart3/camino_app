import '../services/walking_day_store.dart';
import 'today_progress.dart';
import 'diary_tools.dart';
import 'feature_navigation.dart';
import 'personal_library.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../services/settings_service.dart';
import '../services/camino_plan_store.dart';
import '../services/recent_walk.dart';
import '../services/navigation_session.dart';
import 'app_title.dart';
import 'app_logo.dart';
import 'screens.dart'
    show StageListScreen, AccommodationBrowser, LocationDetailScreen;
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
  bool loading = true;
  String? planError;
  List<CaminoPlan> plans = [];
  ItineraryDay? next;
  SavedWalkingDay? todayRoute;
  int revision = 0;
  final store = CaminoPlanStore.instance;
  @override
  void initState() {
    super.initState();
    load();
  }

  int? lastTab;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selected = context
        .dependOnInheritedWidgetOfExactType<FeatureNavigation>()
        ?.selected;
    if (selected == 0 && lastTab != null && lastTab != 0) load();
    lastTab = selected;
  }

  Future<void> load() async {
    final token = ++revision;
    Stage? stage;
    try {
      final saved = await RecentWalk.load();
      final session = NavigationSession.instance;
      final id = session.active ? session.stageId : saved?.$1;
      if (id != null) stage = await widget.repository.stage(id);
    } catch (_) {
      /* Browsing remains available if the remembered stage is missing. */
    }
    List<CaminoPlan> loaded = [];
    ItineraryDay? upcoming;
    String? error;
    SavedWalkingDay? selectedRoute;
    try {
      loaded = await store.plans();
      final days = <ItineraryDay>[];
      for (final plan in loaded) {
        days.addAll(await store.days(plan.id));
      }
      upcoming = nextPlannedDay(days, DateTime.now());
      final now = DateTime.now();
      bool today(SavedWalkingDay d) {
        final date = DateTime.tryParse(d.date ?? '');
        return date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }

      selectedRoute = days.map((d) => d.route).where(today).firstOrNull;
      selectedRoute ??= (await WalkingDayStore().load())
          .where(today)
          .firstOrNull;
    } catch (_) {
      error = 'Your saved plans could not be loaded.';
    }
    if (!mounted || token != revision) return;
    setState(() {
      recent = stage;
      plans = loaded;
      next = upcoming;
      todayRoute = selectedRoute;
      planError = error;
      loading = false;
    });
  }

  Future<void> open(Widget screen) async {
    if (FeatureNavigation.handle(context, screen)) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await load();
  }

  Future<void> openStay(ItineraryDay day) async {
    try {
      final stay = day.stay;
      final place = stay == null
          ? null
          : await widget.repository.accommodationById(stay.kind, stay.id);
      if (!mounted) return;
      if (place != null) {
        await open(AccommodationBrowser(places: [place], initial: place));
      } else {
        final locations = await widget.repository.locationsByIds({day.endId});
        if (!mounted) return;
        final location = locations[day.endId];
        if (location == null) throw StateError('Location unavailable');
        await open(
          LocationDetailScreen(
            repository: widget.repository,
            location: location,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this stay. Please try again.'),
          ),
        );
      }
    }
  }

  void openPlans() => open(
    CaminoPlansScreen(repository: widget.repository, settings: widget.settings),
  );
  @override
  Widget build(BuildContext context) {
    final day = next;
    final now = DateTime.now();
    final date = DateTime.tryParse(day?.route.date ?? '');
    final isToday =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
                  Row(
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const Text('One step at a time.'),
                          ],
                        ),
                      ),
                    ],
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
                              isToday
                                  ? 'Today’s plan'
                                  : day.route.date == null
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
                                  ? 'Planned: ${(day.metres! / 1000).toStringAsFixed(1)} km / ${navigationTime(Duration(seconds: day.seconds!))}'
                                  : 'Distance and walking time not yet estimated',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              day.stay == null
                                  ? 'Accommodation not chosen'
                                  : '${day.stay!.name} (${day.stay!.status})',
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.bed_outlined),
                              label: Text(
                                day.stay == null
                                    ? 'Choose accommodation'
                                    : isToday
                                    ? 'Tonight’s accommodation'
                                    : 'View chosen stay',
                              ),
                              onPressed: () => openStay(day),
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
                  if (todayRoute != null || recent != null)
                    TodayProgress(
                      key: ValueKey('${recent?.id}/${todayRoute?.toJson()}'),
                      stage: recent,
                      plannedDay: todayRoute,
                      repository: widget.repository,
                      settings: widget.settings,
                    ),
                  if (recent != null) ...[
                    Text(
                      'Your current stage',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(recent!.name),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Continue on the map'),
                      onPressed: () => open(
                        MapScreen(
                          repository: widget.repository,
                          settings: widget.settings,
                          stage: recent!,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Ahead of me'),
                          onPressed: () => open(
                            AheadScreen(
                              repository: widget.repository,
                              settings: widget.settings,
                              stage: recent!,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.landscape_outlined),
                          label: const Text('Elevation'),
                          onPressed: () => open(
                            ElevationScreen(
                              repository: widget.repository,
                              stage: recent!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    FilledButton.icon(
                      icon: const Icon(Icons.route),
                      label: const Text('Choose a stage to walk'),
                      onPressed: () => open(
                        StageListScreen(
                          repository: widget.repository,
                          settings: widget.settings,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const TodayDiaryButton(),
                  const Divider(height: 32),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('My Camino plan'),
                    onPressed: openPlans,
                  ),
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
                    icon: const Icon(Icons.book_outlined),
                    label: const Text('Favourites & diary'),
                    onPressed: () => open(
                      PersonalLibraryScreen(repository: widget.repository),
                    ),
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
