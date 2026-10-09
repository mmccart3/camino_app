import 'plan_pdf_screen.dart';
import '../services/plan_pdf_data.dart';
import 'unestimated_day_screen.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/camino_plan_store.dart';
import '../services/settings_service.dart';
import '../services/walking_day.dart';
import '../services/walking_day_store.dart';
import '../services/walking_time.dart';
import 'walking_day_screen.dart';
import 'planned_stay.dart';
import 'screens.dart';

Future<bool> _confirmDelete(BuildContext context, String label) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text(
          'This removes the saved plan data on this device. It does not cancel any accommodation booking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _planName(BuildContext context, {String value = ''}) =>
    showDialog<String>(context: context, builder: (_) => _NameDialog(value));

class _NameDialog extends StatefulWidget {
  final String value;
  const _NameDialog(this.value);
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Plan name'),
    content: TextField(controller: controller, autofocus: true, maxLength: 100),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class CaminoPlansScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final CaminoPlanStore? store;
  const CaminoPlansScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.store,
  });
  @override
  State<CaminoPlansScreen> createState() => _CaminoPlansScreenState();
}

class _CaminoPlansScreenState extends State<CaminoPlansScreen> {
  CaminoPlanStore get store => widget.store ?? CaminoPlanStore.instance;
  List<CaminoPlan> plans = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await store.plans();
      if (mounted) {
        setState(() {
          plans = result;
          busy = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not load your plans. Please retry.';
        });
      }
    }
  }

  Future<void> create() async {
    final name = await _planName(context);
    if (name == null || !mounted) return;
    setState(() => busy = true);
    try {
      final id = await store.create(name);
      if (!mounted) return;
      await open(CaminoPlan(id, name));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the plan.')),
        );
      }
    }
    await load();
  }

  Future<void> open(CaminoPlan plan) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CaminoPlanScreen(
          repository: widget.repository,
          settings: widget.settings,
          plan: plan,
          store: store,
        ),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Camino plan'), centerTitle: true),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Build your own day-by-day itinerary and record where you plan to stay.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Create a plan'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Retry')),
          ],
          for (final plan in plans)
            ListTile(
              title: Text(plan.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : () => open(plan),
            ),
          if (!busy && plans.isEmpty && error == null)
            const Text('No saved itineraries yet.'),
          const SizedBox(height: 24),
          const Text(
            'Plans, stays, references and notes are stored on this device, separately from guide updates. No account or app cloud sync is used. Device backups may include them. Delete a plan to remove its data. Booking websites need internet; recording a stay here does not make or cancel a booking.',
          ),
        ],
      ),
    ),
  );
}

class CaminoPlanScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final CaminoPlan plan;
  final CaminoPlanStore store;
  const CaminoPlanScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.plan,
    required this.store,
  });
  @override
  State<CaminoPlanScreen> createState() => _CaminoPlanScreenState();
}

class _CaminoPlanScreenState extends State<CaminoPlanScreen> {
  List<ItineraryDay> days = [];
  Map<int, Location> breakLocations = {};
  late String name = widget.plan.name;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> load() async {
    try {
      final result = await widget.store.days(widget.plan.id);
      Map<int, Location> stops = {};
      try {
        stops = await widget.repository.locationsByIds(
          result.expand((day) => day.route.breaks.keys).toSet(),
        );
      } catch (_) {
        // Saved plans remain readable if guide location names are unavailable.
      }
      if (mounted) {
        setState(() {
          days = result;
          breakLocations = stops;
          busy = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not load itinerary days. Please retry.';
        });
      }
    }
  }

  Future<void> change(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      message('Could not save the change. Please retry.');
    }
    await load();
  }

  Future<void> editDay([ItineraryDay? existing]) async {
    String? nextDate;
    if (days.isNotEmpty) {
      final last = DateTime.tryParse(days.last.route.date ?? '');
      if (last != null) {
        nextDate = DateTime(
          last.year,
          last.month,
          last.day + 1,
        ).toIso8601String().split('T').first;
      }
    }
    final route = await Navigator.push<SavedWalkingDay>(
      context,
      MaterialPageRoute(
        builder: (_) => WalkingDayScreen(
          repository: widget.repository,
          settings: widget.settings,
          itineraryEditor: true,
          initialDay: existing?.hasEstimate == true ? existing?.route : null,
          initialStartId:
              existing?.startId ?? (days.isNotEmpty ? days.last.endId : null),
          initialFinishId: existing?.endId,
          initialDate: existing?.route.date ?? nextDate,
        ),
      ),
    );
    if (route == null || !mounted) return;
    await change(() async {
      final planner = await WalkingDayPlanner.load(widget.repository);
      final day = planner.calculate(route.pathIds, route.pace);
      await widget.store.saveDay(
        ItineraryDay.fromWalkingDay(
          widget.plan.id,
          route,
          day,
          previous: existing,
        ),
      );
      if (existing?.stay != null && existing!.endId != day.places.last.id) {
        message(
          'Destination changed; the previous stay was removed from this day. Any real booking remains unchanged.',
        );
      }
    });
  }

  Future<void> unestimated([ItineraryDay? existing]) async {
    final day = await Navigator.push<ItineraryDay>(
      context,
      MaterialPageRoute(
        builder: (_) => UnestimatedDayScreen(
          repository: widget.repository,
          planId: widget.plan.id,
          pace: widget.settings.paceKmh,
          previous: days.lastOrNull,
          existing: existing,
        ),
      ),
    );
    if (day != null && mounted) {
      await change(() async {
        await widget.store.saveDay(day);
        if (existing?.stay != null && existing!.endId != day.endId) {
          message(
            'Destination changed; the previous stay was removed. Any real booking remains unchanged.',
          );
        }
      });
    }
  }

  void sharePlan([ItineraryDay? day]) {
    final snapshot = List<ItineraryDay>.of(day == null ? days : [day]);
    final title = name;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanPdfScreen(
          load: () => PlanPdfData.itinerary(title, snapshot, widget.repository),
        ),
      ),
    );
  }

  Future<void> location(ItineraryDay day) async {
    try {
      final places = await widget.repository.locationsByIds({day.endId});
      if (!mounted) return;
      if (places[day.endId] == null) {
        message(
          'This location is no longer in the guide. Your saved stay is retained.',
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(
            repository: widget.repository,
            location: places[day.endId]!,
          ),
        ),
      );
      await load();
    } catch (_) {
      message('Could not open this location.');
    }
  }

  Future<void> accommodation(ItineraryDay day) async {
    try {
      final stay = day.stay!;
      final List<Accommodation> places = stay.kind == 'albergue'
          ? await widget.repository.albergues(day.endId)
          : await widget.repository.privateAccommodation(day.endId);
      final match = places.where((p) => p.id == stay.id).firstOrNull;
      if (!mounted) return;
      if (match == null) {
        message(
          'This accommodation is no longer in the guide. Your saved booking details are retained.',
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AccommodationDetail(
            place: match,
            kind: stay.kind == 'albergue'
                ? 'Albergue'
                : 'Private accommodation',
          ),
        ),
      );
      await load();
    } catch (_) {
      message('Could not open accommodation details.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(name),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Share plan',
          icon: const Icon(Icons.share_outlined),
          onPressed: busy || days.isEmpty ? null : () => sharePlan(),
        ),
        IconButton(
          tooltip: 'Rename plan',
          icon: const Icon(Icons.edit_outlined),
          onPressed: busy
              ? null
              : () async {
                  final value = await _planName(context, value: name);
                  if (value != null && mounted) {
                    await change(() async {
                      await widget.store.rename(widget.plan.id, value);
                      name = value;
                    });
                  }
                },
        ),
        IconButton(
          tooltip: 'Delete plan',
          icon: const Icon(Icons.delete_outline),
          onPressed: busy
              ? null
              : () async {
                  if (!await _confirmDelete(context, 'this plan') || !mounted) {
                    return;
                  }
                  try {
                    await widget.store.deletePlan(widget.plan.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    message('Could not delete the plan.');
                  }
                },
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Retry')),
          ],
          if (!busy && error == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your journey',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        Text('${days.length} planned days'),
                        Text(
                          '${(days.where((d) => d.hasEstimate).fold<double>(0, (a, d) => a + d.metres!) / 1000).toStringAsFixed(1)} km estimated',
                        ),
                        Text(
                          '${WalkingTime.format(Duration(seconds: days.where((d) => d.hasEstimate).fold<int>(0, (a, d) => a + d.seconds!)))} walking',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${days.where((d) => d.stay == null).length} days without a chosen stay',
                    ),
                    Text(
                      '${days.where((d) => d.stay?.status == "Considering").length} stays marked Considering',
                    ),
                    if (days.any((d) => !d.hasEstimate))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${days.where((d) => !d.hasEstimate).length} days have no estimates and are excluded from these totals.',
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved estimates. Edit a day to recalculate.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || error != null ? null : () => editDay(),
            icon: const Icon(Icons.add),
            label: const Text('Add a day'),
          ),
          OutlinedButton.icon(
            onPressed: busy || error != null || days.isEmpty
                ? null
                : () => sharePlan(),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Share plan PDF'),
          ),
          if (!busy && error == null && days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Your journey starts here. Add your first walking day, or a day without estimates below.',
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < days.length; i++) dayCard(days[i], i),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || error != null ? null : () => editDay(),
            icon: const Icon(Icons.add),
            label: const Text('Add walking day'),
          ),
          OutlinedButton(
            onPressed: busy || error != null ? null : () => unestimated(),
            child: const Text('Add day without estimates / rest day'),
          ),
          const Text(
            'Each new day starts at the previous destination. You can change dates to leave rest days. Only complete recorded routes can be estimated.',
          ),
        ],
      ),
    ),
  );
  Widget dayCard(ItineraryDay day, int index) {
    final warning = index > 0 ? day.warningAfter(days[index - 1]) : null;
    final date = DateTime.tryParse(day.route.date ?? '');
    final today = DateUtils.isSameDay(date, DateTime.now());
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: today
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: today ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${today ? "Today · " : ""}Day ${index + 1} | ${date == null ? "Date not set" : MaterialLocalizations.of(context).formatMediumDate(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${day.startName} → ${day.endName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              day.hasEstimate
                  ? '${(day.metres! / 1000).toStringAsFixed(2)} km | ${WalkingTime.format(Duration(seconds: day.seconds!))} walking'
                  : 'Distance and walking time: estimates unavailable',
            ),
            Text(
              day.hasEstimate
                  ? 'Depart ${walkingDayClock(day.route.departureMinutes, Duration.zero)} | Arrive approximately ${walkingDayClock(day.route.departureMinutes, day.totalDuration)}'
                  : 'Depart ${walkingDayClock(day.route.departureMinutes, Duration.zero)} / Arrival estimate unavailable',
            ),
            if (warning != null)
              Text(
                warning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(height: 28),
            if (day.stay == null)
              const Text('Accommodation not chosen')
            else ...[
              Text(
                day.stay!.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Chip(
                avatar: Icon(
                  day.stay!.status == 'Confirmed'
                      ? Icons.check_circle_outline
                      : day.stay!.status == 'Booked'
                      ? Icons.event_available
                      : Icons.bed_outlined,
                  size: 20,
                ),
                label: Text(
                  day.stay!.status == 'Considering'
                      ? 'Planned'
                      : day.stay!.status,
                ),
              ),
            ],
            if (today && day.hasEstimate && day.route.pathIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions_walk),
                  label: const Text("Start today's walk"),
                  onPressed: busy
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WalkingDayScreen(
                              repository: widget.repository,
                              settings: widget.settings,
                              initialDay: day.route,
                            ),
                          ),
                        ),
                ),
              ),
            ExpansionTile(
              key: PageStorageKey('itinerary-day-${day.id}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Day details'),
              subtitle: Text('${day.route.breaks.length} planned breaks'),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.route.breaks.isEmpty) const Text('No planned breaks'),
                for (final stop in day.route.breaks.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${breakLocations[stop.key]?.name ?? "Location ${stop.key}"}: ${stop.value} min break',
                    ),
                  ),
                if (day.stay != null) ...[
                  if (day.stay!.reference.isNotEmpty)
                    Text('Reference: ${day.stay!.reference}'),
                  if (day.stay!.notes.isNotEmpty) Text(day.stay!.notes),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => day.hasEstimate
                                ? editDay(day)
                                : unestimated(day),
                      child: const Text('Edit day'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => sharePlan(day),
                      child: const Text('Share day PDF'),
                    ),
                    if (!day.hasEstimate)
                      TextButton(
                        onPressed: busy ? null : () => editDay(day),
                        child: const Text('Choose route for estimates'),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => location(day),
                      child: Text(
                        day.stay == null
                            ? 'Choose accommodation'
                            : 'View destination',
                      ),
                    ),
                    if (day.stay != null) ...[
                      TextButton(
                        onPressed: busy ? null : () => accommodation(day),
                        child: const Text('Open accommodation / book'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final stay = await editPlannedStay(
                                  context,
                                  day.stay!,
                                );
                                if (stay != null && mounted) {
                                  await change(
                                    () => widget.store.setStay(
                                      day.id,
                                      stay,
                                      locationId: day.endId,
                                    ),
                                  );
                                }
                              },
                        child: const Text('Edit booking details'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await _confirmDelete(
                                      context,
                                      'this saved stay',
                                    ) &&
                                    mounted) {
                                  await change(
                                    () => widget.store.setStay(
                                      day.id,
                                      null,
                                      locationId: day.endId,
                                    ),
                                  );
                                }
                              },
                        child: const Text('Remove stay'),
                      ),
                    ],
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await _confirmDelete(context, 'this day') &&
                                  mounted) {
                                await change(
                                  () => widget.store.deleteDay(day.id),
                                );
                              }
                            },
                      child: const Text('Delete day'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
