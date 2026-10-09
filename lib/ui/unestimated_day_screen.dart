import '../data/walking_location_order.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/camino_plan_store.dart';
import '../services/walking_day_store.dart';

/// Allows itinerary planning even beyond the currently recorded guide tracks.
class UnestimatedDayScreen extends StatefulWidget {
  final CaminoRepository repository;
  final int planId;
  final int? initialDestinationId, initialStartId;
  final double pace;
  final ItineraryDay? previous, existing;
  const UnestimatedDayScreen({
    super.key,
    required this.repository,
    required this.planId,
    required this.pace,
    this.initialDestinationId,
    this.initialStartId,
    this.previous,
    this.existing,
  });
  @override
  State<UnestimatedDayScreen> createState() => _UnestimatedDayScreenState();
}

class _UnestimatedDayScreenState extends State<UnestimatedDayScreen> {
  List<Location> places = [];
  int? start, finish;
  String? date, error;
  int departure = 480;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    start =
        widget.existing?.startId ??
        widget.initialStartId ??
        widget.previous?.endId;
    finish = widget.existing?.endId ?? widget.initialDestinationId;
    date = widget.existing?.route.date;
    departure = widget.existing?.route.departureMinutes ?? 480;
    if (widget.existing == null) {
      final last = DateTime.tryParse(widget.previous?.route.date ?? '');
      if (last != null) {
        date = DateTime(
          last.year,
          last.month,
          last.day + 1,
        ).toIso8601String().split('T').first;
      }
    }
    load();
  }

  Future<void> load() async {
    try {
      final ids = <int, Location>{};
      final paths = <Path>[];
      for (final stage in await widget.repository.stages()) {
        paths.addAll(await widget.repository.paths(stage.id));
        for (final location in await widget.repository.locations(stage.id)) {
          ids[location.id] = location;
        }
      }
      if (!mounted) return;
      setState(() {
        places = orderWalkingLocations(ids.values, paths);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load locations. Please retry.';
        });
      }
    }
  }

  Future<void> choose(bool origin) async {
    final choices = origin
        ? (List<Location>.of(places)..sort((a, b) => a.name.compareTo(b.name)))
        : places.skip(places.indexWhere((p) => p.id == start) + 1).toList();
    final selected = await showDialog<Location>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(origin ? 'Starting location' : 'Destination'),
        children: [
          if (choices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No further locations on this route.'),
            ),
          for (final place in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, place),
              child: Text(place.name),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (origin) {
          start = selected.id;
        } else {
          finish = selected.id;
        }
      });
    }
  }

  Location? place(int? id) => places.where((p) => p.id == id).firstOrNull;
  void save() {
    final a = place(start), b = place(finish);
    if (a == null || b == null) return;
    final old = widget.existing;
    Navigator.pop(
      context,
      ItineraryDay(
        id: old?.id ?? 0,
        planId: widget.planId,
        order: old?.order ?? 0,
        startId: a.id,
        endId: b.id,
        startName: a.name,
        endName: b.name,
        metres: null,
        seconds: null,
        route: SavedWalkingDay(
          old?.route.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          [],
          widget.pace,
          date,
          departureMinutes: departure,
        ),
        stay: old?.endId == b.id ? old?.stay : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Plan without estimates'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose your own destinations. Distance, walking time and arrival time are unavailable until you select a complete recorded route. You can also use this for a rest day by choosing the same start and finish.',
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Retry')),
          ],
          OutlinedButton(
            onPressed: loading ? null : () => choose(true),
            child: Text('From: ${place(start)?.name ?? "Choose location"}'),
          ),
          OutlinedButton(
            onPressed: loading ? null : () => choose(false),
            child: Text('To: ${place(finish)?.name ?? "Choose location"}'),
          ),
          TextButton.icon(
            onPressed: place(start) == null
                ? null
                : () => setState(() => finish = start),
            icon: const Icon(Icons.hotel_outlined),
            label: const Text('Rest day / stay at starting location'),
          ),
          TextButton(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(date ?? '') ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected != null && mounted) {
                setState(
                  () => date = selected.toIso8601String().split('T').first,
                );
              }
            },
            child: Text(date ?? 'Choose date (optional)'),
          ),
          if (date != null)
            TextButton(
              onPressed: () => setState(() => date = null),
              child: const Text('Remove date'),
            ),
          TextButton(
            onPressed: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: departure ~/ 60,
                  minute: departure % 60,
                ),
              );
              if (selected != null && mounted) {
                setState(
                  () => departure = selected.hour * 60 + selected.minute,
                );
              }
            },
            child: Text(
              'Departure: ${TimeOfDay(hour: departure ~/ 60, minute: departure % 60).format(context)}',
            ),
          ),
          FilledButton(
            onPressed: place(start) == null || place(finish) == null
                ? null
                : save,
            child: const Text('Save itinerary day'),
          ),
        ],
      ),
    ),
  );
}
