import 'plan_pdf_screen.dart';
import '../services/plan_pdf_data.dart';
import '../services/walking_time.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/walking_day.dart';
import '../services/walking_day_store.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import 'elevation_chart.dart';

String formatWalkingDayTime(Duration duration) => WalkingTime.format(duration);

class WalkingDayScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final bool itineraryEditor;
  final SavedWalkingDay? initialDay;
  final int? initialStartId;
  final int? initialFinishId;
  final String? initialDate;
  const WalkingDayScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.itineraryEditor = false,
    this.initialDay,
    this.initialStartId,
    this.initialFinishId,
    this.initialDate,
  });
  @override
  State<WalkingDayScreen> createState() => _WalkingDayScreenState();
}

class _WalkingDayScreenState extends State<WalkingDayScreen> {
  final store = WalkingDayStore();
  WalkingDayPlanner? planner;
  List<SavedWalkingDay> saved = [];
  List<List<int>> options = [];
  WalkingDay? day;
  int? start, finish;
  int option = 0;
  int departureMinutes = 480;
  Map<int, int> breaks = {};
  late double pace = widget.settings.paceKmh;
  String? date, editingId, error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final loaded = await WalkingDayPlanner.load(widget.repository);
      final plans = widget.itineraryEditor
          ? <SavedWalkingDay>[]
          : await store.load();
      if (!mounted) return;
      setState(() {
        planner = loaded;
        saved = plans;
        busy = false;
        error = null;
        start = widget.initialStartId;
        finish = widget.initialFinishId;
        date = widget.initialDate;
      });
      if (widget.initialDay != null) {
        open(widget.initialDay!);
      } else if (start != null && finish != null) {
        setState(() => calculate(findRoutes: true));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not load walking days. Retry, or delete saved plans if their data is damaged.';
        });
      }
    }
  }

  void calculate({bool findRoutes = false}) {
    day = null;
    error = null;
    if (start == null || finish == null || planner == null) return;
    try {
      if (findRoutes) {
        options = planner!.routes(start!, finish!);
        option = 0;
      }
      if (options.isEmpty) {
        error =
            'No complete forward route is available between these places. Choose a destination ahead with downloaded guide tracks.';
      } else {
        day = planner!.calculate(options[option], pace);
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<void> choose(bool isStart) async {
    final places = isStart
        ? (planner!.locations.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name)))
        : planner!.orderedLocations
              .skip(
                planner!.orderedLocations.indexWhere((p) => p.id == start) + 1,
              )
              .toList();
    final selected = await showDialog<Location>(
      context: context,
      builder: (_) => _PlacePicker(
        places: places,
        title: isStart ? 'Starting place' : 'Destination',
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        start = selected.id;
      } else {
        finish = selected.id;
      }
      calculate(findRoutes: true);
    });
  }

  Future<void> nearby() async {
    setState(() {
      busy = true;
    });
    try {
      final fix = await LocationService().current();
      if (!mounted) return;
      if (!fix.accuracy.isFinite || fix.accuracy > 100) {
        throw StateError(
          'Location accuracy is poor. Choose your starting place manually.',
        );
      }
      const distance = Distance(roundResult: false);
      final position = LatLng(fix.latitude, fix.longitude);
      final places =
          planner!.locations.values.where((p) => p.position != null).toList()
            ..sort(
              (a, b) => distance(
                position,
                a.position!,
              ).compareTo(distance(position, b.position!)),
            );
      if (places.isEmpty) throw StateError('No nearby places are available.');
      final nearest = places.first;
      final metres = distance(position, nearest.position!);
      final use = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Start at ${nearest.name}?'),
          content: Text(
            'This place is ${(metres / 1000).toStringAsFixed(1)} km away in a straight line. The plan starts at the recorded route near this place, not your GPS position.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use this place'),
            ),
          ],
        ),
      );
      if (use == true && mounted) {
        setState(() {
          start = nearest.id;
          calculate(findRoutes: true);
        });
      }
    } catch (e) {
      if (mounted) message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> save() async {
    if (day == null) return;
    setState(() {
      busy = true;
    });
    try {
      final id = editingId ?? DateTime.now().microsecondsSinceEpoch.toString();
      final plan = SavedWalkingDay(
        id,
        List.of(options[option]),
        pace,
        date,
        departureMinutes: departureMinutes,
        breaks: {
          for (final place in day!.places.skip(1).take(day!.places.length - 2))
            if ((breaks[place.id] ?? 0) > 0) place.id: breaks[place.id]!,
        },
      );
      if (widget.itineraryEditor) {
        if (mounted) Navigator.pop(context, plan);
        return;
      }
      final next = [...saved.where((p) => p.id != id), plan];
      await store.save(next);
      if (mounted) {
        setState(() {
          saved = next;
          editingId = id;
        });
      }
      if (mounted) message('Walking day saved on this device.');
    } catch (_) {
      if (mounted) {
        message('Could not save your walking day. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void open(SavedWalkingDay plan) {
    try {
      final result = planner!.calculate(plan.pathIds, plan.pace);
      setState(() {
        start = result.places.first.id;
        finish = result.places.last.id;
        pace = plan.pace;
        date = plan.date;
        departureMinutes = plan.departureMinutes;
        breaks = Map.of(plan.breaks);
        editingId = plan.id;
        options = [List.of(plan.pathIds)];
        option = 0;
        day = result;
        error = null;
      });
    } catch (_) {
      message(
        'This saved route is unavailable in the current guide. Create a new plan or delete it.',
      );
    }
  }

  Future<void> delete({String? id}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          id == null
              ? 'Delete all saved walking days?'
              : 'Delete this walking day?',
        ),
        content: const Text('This cannot be undone.'),
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
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
    });
    try {
      final next = id == null
          ? <SavedWalkingDay>[]
          : saved.where((p) => p.id != id).toList();
      if (id == null) {
        await store.clear();
      } else {
        await store.save(next);
      }
      if (mounted) {
        setState(() {
          saved = next;
          if (id == null || editingId == id) editingId = null;
        });
      }
      if (planner == null) await load();
    } catch (_) {
      if (mounted) message('Could not delete saved plans. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> editBreak(Location place) async {
    final duration = await showDialog<int>(
      context: context,
      builder: (_) =>
          _BreakDialog(name: place.name, minutes: breaks[place.id] ?? 0),
    );
    if (duration == null || !mounted) return;
    setState(() {
      if (duration == 0) {
        breaks.remove(place.id);
      } else {
        breaks[place.id] = duration;
      }
    });
  }

  String routeName(List<int> ids) {
    final places = [
      for (final id in ids)
        planner!.locations[planner!.legs[id]!.path.originLocationId]!.name,
      planner!
          .locations[planner!.legs[ids.last]!.path.destinationLocationId]!
          .name,
    ];
    return places.join(' > ');
  }

  String savedName(SavedWalkingDay plan) {
    try {
      return routeName(plan.pathIds);
    } catch (_) {
      return 'Saved route unavailable';
    }
  }

  void shareDay() {
    final current = day;
    if (current == null) return;
    final validBreaks = <int, int>{
      for (final place
          in current.places.skip(1).take(current.places.length - 2))
        if ((breaks[place.id] ?? 0) > 0) place.id: breaks[place.id]!,
    };
    final route = SavedWalkingDay(
      editingId ?? 'preview',
      List.of(options[option]),
      pace,
      date,
      departureMinutes: departureMinutes,
      breaks: validBreaks,
    );
    final snapshot = PlanPdfData.walkingDay(current, route);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanPdfScreen(load: () async => snapshot),
      ),
    );
  }

  void privacy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your walking-day privacy'),
      content: const SingleChildScrollView(
        child: Text(
          'Plans contain your chosen route, optional date, starting time, planned breaks and walking pace. They are stored in this app on your device, separately from the guide database. This planner sends no plans or location history to us and uses no analytics.\n\n'
          'Nearby start is optional. It requests one location fix to suggest a place; the coordinates are not saved. No background tracking is started.\n\n'
          'You can delete individual plans or all saved plans here. Your phone\'s operating-system backup or device-transfer settings may include app data; the app does not provide cloud synchronisation.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final schedule = day?.timetable(breaks);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itineraryEditor ? 'Plan itinerary day' : 'My walking day',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share walking day',
            icon: const Icon(Icons.share_outlined),
            onPressed: busy || day == null ? null : shareDay,
          ),
          IconButton(
            onPressed: privacy,
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Walking-day privacy',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (busy) const LinearProgressIndicator(),
            const Text(
              'Plan between any two places along a connected forward route. Estimates use the available recorded tracks.',
            ),
            const SizedBox(height: 12),
            if (planner != null) ...[
              OutlinedButton(
                onPressed: busy ? null : () => choose(true),
                child: Text(
                  start == null
                      ? 'Choose starting place'
                      : 'From: ${planner!.locations[start]?.name}',
                ),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => choose(false),
                child: Text(
                  finish == null
                      ? 'Choose destination'
                      : 'To: ${planner!.locations[finish]?.name}',
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : nearby,
                icon: const Icon(Icons.my_location),
                label: const Text('Find a nearby starting place'),
              ),
              Text('Flat-ground pace: ${pace.toStringAsFixed(1)} km/h'),
              Slider(
                value: pace,
                min: 1,
                max: 8.5,
                divisions: 75,
                label: pace.toStringAsFixed(1),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        pace = double.parse(v.toStringAsFixed(1));
                        calculate();
                      }),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(date ?? '') ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null && mounted) {
                          setState(() {
                            date = selected.toIso8601String().split('T').first;
                          });
                        }
                      },
                child: Text(
                  date == null
                      ? 'Add a date (optional)'
                      : 'Walking date: $date',
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          date = null;
                        }),
                  child: const Text('Remove date'),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(
                  'Starting time: ${walkingDayClock(departureMinutes, Duration.zero)}',
                ),
                onPressed: busy
                    ? null
                    : () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: departureMinutes ~/ 60,
                            minute: departureMinutes % 60,
                          ),
                        );
                        if (time != null && mounted) {
                          setState(() {
                            departureMinutes = time.hour * 60 + time.minute;
                          });
                        }
                      },
              ),
              const Text(
                'Use local Camino time. Arrival estimates include your planned breaks.',
              ),
              if (options.length > 1) ...[
                const Text('Choose your route:'),
                for (var i = 0; i < options.length; i++)
                  ListTile(
                    leading: Icon(
                      option == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(routeName(options[i])),
                    onTap: busy
                        ? null
                        : () => setState(() {
                            option = i;
                            calculate();
                          }),
                  ),
              ],
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (planner == null && !busy)
              TextButton(
                onPressed: () {
                  setState(() {
                    busy = true;
                  });
                  load();
                },
                child: const Text('Retry'),
              ),
            if (day != null) ...[
              const Divider(),
              Text(day!.name, style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${(day!.metres / 1000).toStringAsFixed(2)} km | ${formatWalkingDayTime(day!.walkingTime)} walking',
              ),
              Text(
                'Ascent ${day!.ascent.round()} m | Descent ${day!.descent.round()} m',
              ),
              Text(
                'Planned breaks: ${formatWalkingDayTime(schedule!.totalBreak)}',
              ),
              Text(
                'Overall duration: ${formatWalkingDayTime(schedule.totalDuration)}',
              ),
              const Text(
                'Walking time excludes breaks. Arrival times include planned breaks but exclude unplanned stops and accommodation detours. Elevation is based on recorded track points.',
              ),
              if (day!.joinMetres > 1)
                Text(
                  'Small joins between stage recordings total about ${day!.joinMetres.round()} m and are excluded from the estimates.',
                ),
              ElevationChart(profile: day!.profile),
              Text(
                'Places and approximate arrival times',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (var i = 0; i < day!.places.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(day!.places[i].name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i == 0 ? 'Start' : 'Approx. arrival'}: ${walkingDayClock(departureMinutes, schedule.arrivals[i])}',
                      ),
                      if (i > 0 && i < day!.places.length - 1) ...[
                        if ((breaks[day!.places[i].id] ?? 0) > 0) ...[
                          Text('Break: ${breaks[day!.places[i].id]} minutes'),
                          Text(
                            'Departure: ${walkingDayClock(departureMinutes, schedule.departures[i])}',
                          ),
                        ],
                        TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => editBreak(day!.places[i]),
                          icon: const Icon(Icons.free_breakfast_outlined),
                          label: Text(
                            (breaks[day!.places[i].id] ?? 0) == 0
                                ? 'Add break'
                                : 'Edit break',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: busy ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  widget.itineraryEditor
                      ? 'Save itinerary day'
                      : editingId == null
                      ? 'Save walking day'
                      : 'Update saved walking day',
                ),
              ),
            ],
            if (!widget.itineraryEditor && planner != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        start = null;
                        finish = null;
                        day = null;
                        options = [];
                        editingId = null;
                        date = null;
                        departureMinutes = 480;
                        breaks = {};
                        error = null;
                        pace = widget.settings.paceKmh;
                      }),
                child: const Text('New walking day'),
              ),
            if (!widget.itineraryEditor) ...[
              const Divider(),
              Text(
                'Saved walking days',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (saved.isEmpty) const Text('No saved walking days.'),
              for (final plan in saved)
                ListTile(
                  title: Text(
                    planner == null ? 'Saved walking day' : savedName(plan),
                  ),
                  subtitle: Text(
                    '${plan.date ?? 'No date'} | ${walkingDayClock(plan.departureMinutes, Duration.zero)} | ${plan.pace.toStringAsFixed(1)} km/h',
                  ),
                  onTap: busy || planner == null ? null : () => open(plan),
                  trailing: IconButton(
                    tooltip: 'Delete walking day',
                    onPressed: busy ? null : () => delete(id: plan.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              TextButton(
                onPressed: busy ? null : () => delete(),
                child: const Text('Delete all saved walking days'),
              ),
            ],
            TextButton(
              onPressed: privacy,
              child: const Text('How your plans are stored'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacePicker extends StatefulWidget {
  final List<Location> places;
  final String title;
  const _PlacePicker({required this.places, required this.title});
  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.places
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Search places'),
              onChanged: (s) => setState(() {
                query = s;
              }),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(filtered[i].name),
                  onTap: () => Navigator.pop(context, filtered[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _BreakDialog extends StatefulWidget {
  final String name;
  final int minutes;
  const _BreakDialog({required this.name, required this.minutes});
  @override
  State<_BreakDialog> createState() => _BreakDialogState();
}

class _BreakDialogState extends State<_BreakDialog> {
  late final controller = TextEditingController(text: '${widget.minutes}');
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void apply() {
    final minutes = int.tryParse(controller.text.trim());
    if (minutes == null || minutes < 0 || minutes > 1440) {
      setState(() {
        error = 'Enter whole minutes from 0 to 1440.';
      });
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Break at ${widget.name}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [15, 30, 60])
                ActionChip(
                  label: Text('$minutes min'),
                  onPressed: () => Navigator.pop(context, minutes),
                ),
            ],
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Custom duration (minutes)',
              errorText: error,
            ),
            onSubmitted: (_) => apply(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, 0),
        child: const Text('No break'),
      ),
      FilledButton(onPressed: apply, child: const Text('Apply')),
    ],
  );
}
