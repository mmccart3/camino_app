import 'summary_metric.dart';
import 'coming_up_card.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../services/walking_day_store.dart';
import 'today_progress.dart';
import 'diary_tools.dart';
import 'feature_navigation.dart';
import '../services/walking_day.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../services/settings_service.dart';
import '../services/camino_plan_store.dart';
import '../services/recent_walk.dart';
import '../services/navigation_session.dart';
import 'app_title.dart';
import 'screens.dart'
    show StageListScreen, AccommodationBrowser, LocationDetailScreen;
import 'map_screen.dart';
import 'settings_screen.dart';
import 'camino_plan_screen.dart';
import 'walking_day_screen.dart';
import 'ahead_screen.dart';
import 'elevation_screen.dart';
import '../services/stage_walking_time.dart';
import '../services/walking_time.dart';

String shortTime(Duration? value) =>
    value == null ? 'Walking time unavailable' : WalkingTime.format(value);

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
  LatLng? comingPosition;
  String? comingPositionRoute;
  String get comingRouteKey => '${recent?.id}/${todayRoute?.toJson()}';
  Duration? selectedStageTime;
  Location? stageStart, stageEnd;
  bool loading = true;
  String? planError;
  List<CaminoPlan> plans = [];
  bool hasSavedWalkingDays = false;
  ItineraryDay? next;
  SavedWalkingDay? todayRoute;
  WalkingDay? walkingDay;
  ItineraryDay? tomorrow;
  int revision = 0;
  final store = CaminoPlanStore.instance;
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(refreshWalkingTime);
    load();
  }

  @override
  void dispose() {
    widget.settings.removeListener(refreshWalkingTime);
    super.dispose();
  }

  int timeRevision = 0;
  Future<void> refreshWalkingTime() async {
    final token = ++timeRevision;
    final stage = recent;
    if (stage == null) return;
    Duration? duration;
    try {
      duration = await stageWalkingTime(
        stage,
        widget.repository,
        widget.settings,
      );
    } catch (_) {}
    if (mounted && token == timeRevision && recent?.id == stage.id) {
      setState(() => selectedStageTime = duration);
    }
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
    bool anyWalkingDays = false;
    String? error;
    SavedWalkingDay? selectedRoute;
    WalkingDay? calculated;
    ItineraryDay? tomorrowDay;
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

      selectedRoute = upcoming != null && today(upcoming.route)
          ? upcoming.route
          : null;
      final tomorrowDate = DateTime(
        now.year,
        now.month,
        now.day + 1,
      ).toIso8601String().split('T').first;
      tomorrowDay = days.where((d) => d.route.date == tomorrowDate).firstOrNull;
      final savedWalkingDays = await WalkingDayStore().load();
      anyWalkingDays = savedWalkingDays.isNotEmpty;
      selectedRoute ??= savedWalkingDays.where(today).firstOrNull;
    } catch (_) {
      error = 'Your saved plans could not be loaded.';
    }
    if (selectedRoute != null) {
      try {
        final planner = await WalkingDayPlanner.load(widget.repository);
        calculated = planner.calculate(
          selectedRoute.pathIds,
          selectedRoute.pace,
        );
        final stages = calculated.legs
            .map((leg) => leg.stage)
            .whereType<Stage>()
            .toList();
        stage =
            stages.where((s) => s.id == stage?.id).firstOrNull ??
            stages.firstOrNull;
      } catch (_) {
        stage = null;
        error =
            'Today’s route could not be calculated. Open My Day to review it.';
      }
    }
    Map<int, Location> endpoints = {};
    try {
      if (stage != null) {
        endpoints = await widget.repository.locationsByIds({
          stage.startLocationId,
          stage.finishLocationId,
        });
      }
    } catch (_) {
      error ??= 'Stage locations could not be loaded. Please retry.';
    }
    Duration? duration;
    if (stage != null) {
      try {
        duration = await stageWalkingTime(
          stage,
          widget.repository,
          widget.settings,
        );
      } catch (_) {
        /* Missing route weights have no stored-time fallback. */
      }
    }
    if (!mounted || token != revision) return;
    setState(() {
      recent = stage;
      selectedStageTime = duration;
      stageStart = endpoints[stage?.startLocationId];
      stageEnd = endpoints[stage?.finishLocationId];
      plans = loaded;
      hasSavedWalkingDays = anyWalkingDays;
      next = upcoming;
      todayRoute = selectedRoute;
      walkingDay = calculated;
      tomorrow = tomorrowDay;
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

  bool preparingTonight = false;
  Future<void> openTonight(Location destination) async {
    if (preparingTonight) return;
    setState(() => preparingTonight = true);
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final available = await store.plans();
      bool exists = false;
      for (final plan in available) {
        if ((await store.days(plan.id)).any(
          (day) => day.endId == destination.id && day.route.date == date,
        )) {
          exists = true;
        }
      }
      if (!exists) {
        if (!mounted) return;
        final chosen = await showDialog<int>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Add today to a plan'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Save today’s walk ending in ${destination.name} so you can attach tonight’s accommodation.',
                ),
              ),
              for (final plan in available)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, plan.id),
                  child: Text(plan.name),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, -1),
                child: const Text('Create a new plan for today'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        if (chosen == null) return;
        SavedWalkingDay saved;
        WalkingDay? calculated = walkingDay;
        if (todayRoute != null) {
          saved = todayRoute!;
          if (calculated == null) {
            final planner = await WalkingDayPlanner.load(widget.repository);
            calculated = planner.calculate(saved.pathIds, saved.pace);
          }
        } else {
          final stage = recent;
          if (stage == null || stageStart == null) {
            throw StateError('Choose a stage first');
          }
          final route = await widget.repository.route(stage);
          saved = SavedWalkingDay(
            'today-$date-${stage.id}',
            route.paths.map((p) => p.id).toList(),
            widget.settings.paceKmh,
            date,
          );
          if (route.canGuide) {
            final planner = await WalkingDayPlanner.load(widget.repository);
            calculated = planner.calculate(saved.pathIds, saved.pace);
          }
        }
        final planId = chosen == -1
            ? await store.create('My Camino · $date')
            : chosen;
        final draft = calculated != null
            ? ItineraryDay.fromWalkingDay(planId, saved, calculated)
            : ItineraryDay(
                id: 0,
                planId: planId,
                order: 0,
                startId: stageStart?.id ?? destination.id,
                endId: destination.id,
                startName: stageStart?.name ?? destination.name,
                endName: destination.name,
                metres: null,
                seconds: null,
                route: saved,
              );
        if (draft.endId != destination.id) {
          throw StateError('Destination changed');
        }
        await store.saveDay(draft);
      }
      if (!mounted) return;
      await open(
        LocationDetailScreen(
          repository: widget.repository,
          location: destination,
        ),
      );
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare tonight’s stay. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => preparingTonight = false);
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(now),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!loading &&
                      todayRoute == null &&
                      recent == null &&
                      plans.isEmpty &&
                      !hasSavedWalkingDays)
                    const Text(
                      'One step at a time.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 8),
                  if (loading)
                    const LinearProgressIndicator()
                  else ...[
                    if (planError != null)
                      Card(
                        child: ListTile(
                          title: Text(planError!),
                          trailing: TextButton(
                            onPressed: load,
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                    if (recent == null &&
                        todayRoute == null &&
                        plans.isEmpty &&
                        !hasSavedWalkingDays &&
                        planError == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Plan your Camino',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => open(
                                  StageListScreen(
                                    repository: widget.repository,
                                    settings: widget.settings,
                                  ),
                                ),
                                child: const Text('Choose a starting stage'),
                              ),
                              TextButton(
                                onPressed: () => open(
                                  StageListScreen(
                                    repository: widget.repository,
                                    settings: widget.settings,
                                  ),
                                ),
                                child: const Text('Just browse the stages'),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                todayRoute != null
                                    ? 'TODAY’S WALK'
                                    : 'YOUR SELECTED STAGE',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: caminoYellow),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                walkingDay?.places.first.name ??
                                    stageStart?.name ??
                                    'Choose your next walk',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: caminoYellow,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      walkingDay?.places.last.name ??
                                          stageEnd?.name ??
                                          '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (walkingDay != null) ...[
                                for (final label in walkingDay!.routeLabels)
                                  Text(label),
                              ] else if (recent != null)
                                Text('Stage ${recent!.displayNumber}'),
                              const SizedBox(height: 8),
                              if (walkingDay != null || recent != null)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SummaryMetric(
                                        label: 'Distance',
                                        value: walkingDay != null
                                            ? '${(walkingDay!.metres / 1000).toStringAsFixed(1)} km'
                                            : recent!.distanceMeters == null
                                            ? 'Unavailable'
                                            : '${(recent!.distanceMeters! / 1000).toStringAsFixed(1)} km',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SummaryMetric(
                                        label: 'Walking time',
                                        value: walkingDay != null
                                            ? shortTime(walkingDay!.walkingTime)
                                            : shortTime(selectedStageTime),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  recent == null
                                      ? 'Choose a stage'
                                      : todayRoute == null
                                      ? 'Continue on the map'
                                      : 'Open stage ${recent!.displayNumber} map',
                                ),
                                onPressed: () => open(
                                  recent == null
                                      ? StageListScreen(
                                          repository: widget.repository,
                                          settings: widget.settings,
                                        )
                                      : MapScreen(
                                          repository: widget.repository,
                                          settings: widget.settings,
                                          stage: recent!,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: recent == null
                                          ? null
                                          : () => open(
                                              AheadScreen(
                                                repository: widget.repository,
                                                settings: widget.settings,
                                                stage: recent!,
                                              ),
                                            ),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.directions_walk, size: 22),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Ahead'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: recent == null
                                          ? null
                                          : () => open(
                                              ElevationScreen(
                                                repository: widget.repository,
                                                stage: recent!,
                                              ),
                                            ),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.terrain_outlined,
                                            size: 22,
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Elevation'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: TodayDiaryButton(
                                      label: 'Diary',
                                      compact: true,
                                    ),
                                  ),
                                ],
                              ),
                              if (todayRoute != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('Open My Day'),
                                  onPressed: () => open(
                                    WalkingDayScreen(
                                      repository: widget.repository,
                                      settings: widget.settings,
                                      initialDay: todayRoute,
                                    ),
                                  ),
                                ),
                              if (todayRoute != null || recent != null)
                                TodayProgress(
                                  key: ValueKey(
                                    '${recent?.id}/${todayRoute?.toJson()}',
                                  ),
                                  stage: recent,
                                  plannedDay: todayRoute,
                                  onPosition: (position) => setState(() {
                                    comingPosition = position;
                                    comingPositionRoute = comingRouteKey;
                                  }),
                                  repository: widget.repository,
                                  settings: widget.settings,
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (recent != null &&
                        (todayRoute == null || walkingDay != null))
                      ComingUpCard(
                        repository: widget.repository,
                        settings: widget.settings,
                        stage: recent!,
                        day: walkingDay,
                        position: comingPositionRoute == comingRouteKey
                            ? comingPosition
                            : null,
                      ),
                    if (isToday && day != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.bed_outlined,
                            color: caminoYellow,
                          ),
                          title: const Text('Tonight'),
                          subtitle: Text(
                            day.stay == null
                                ? 'Not yet booked · ${day.endName}'
                                : '${day.stay!.name} · ${day.stay!.status}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openStay(day),
                        ),
                      )
                    else if (walkingDay != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.bed_outlined,
                            color: caminoYellow,
                          ),
                          title: const Text('Tonight'),
                          subtitle: Text(
                            'Not yet booked · ${walkingDay!.places.last.name}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openTonight(walkingDay!.places.last),
                        ),
                      ),
                    if (!isToday && walkingDay == null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.bed_outlined,
                            color: caminoYellow,
                          ),
                          title: const Text('Tonight'),
                          subtitle: Text(
                            'Not yet booked${stageEnd == null ? "" : " · ${stageEnd!.name}"}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: stageEnd == null
                              ? openPlans
                              : () => openTonight(stageEnd!),
                        ),
                      ),
                    if (tomorrow != null)
                      Card(
                        child: ListTile(
                          title: const Text('Tomorrow'),
                          subtitle: Text(
                            '${tomorrow!.startName} → ${tomorrow!.endName}\n${tomorrow!.stay?.name ?? "No stay chosen"}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: openPlans,
                        ),
                      )
                    else if (!isToday && day != null && plan != null)
                      Card(
                        child: ListTile(
                          title: Text(
                            date == null
                                ? 'Next undated walk'
                                : 'Next walk · ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                          ),
                          subtitle: Text('${day.startName} → ${day.endName}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(
                            CaminoPlanScreen(
                              repository: widget.repository,
                              settings: widget.settings,
                              plan: plan,
                              store: store,
                            ),
                          ),
                        ),
                      ),
                    if (todayRoute == null && recent == null)
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Plan my Camino'),
                        onPressed: openPlans,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
