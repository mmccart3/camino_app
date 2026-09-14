import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_assembler.dart';
import '../services/location_service.dart';
import '../services/map_links.dart';
import '../services/safe_links.dart';
import 'widgets.dart';

/// Uses straight-line distance to choose a stored route point or stage start.
/// Google Maps calculates the walking route to the chosen destination.
LatLng? stageEntryPoint(LatLng user, LatLng? start, Iterable<LatLng> points) {
  const distance = Distance(roundResult: false);
  var selected = start;
  var best = start == null ? double.infinity : distance(user, start);
  for (final point in points) {
    if (MapLinks.walkingDirections(point) == null) continue;
    final offset = distance(user, point);
    if (offset < best) {
      selected = point;
      best = offset;
    }
  }
  return selected;
}

class StageDirections extends StatefulWidget {
  final StageRoute route;
  const StageDirections({super.key, required this.route});
  @override
  State<StageDirections> createState() => _StageDirectionsState();
}

class _StageDirectionsState extends State<StageDirections> {
  bool busy = false;
  LatLng? get start => widget.route.locations
      .where((location) => location.id == widget.route.stage.startLocationId)
      .firstOrNull
      ?.position;
  Future<void> open(LatLng destination) async {
    final url = MapLinks.walkingDirections(destination);
    if (url == null) throw StateError('No usable stage coordinates available.');
    await SafeLinks.open(url);
  }

  Future<void> locateAndOpen() async {
    setState(() => busy = true);
    try {
      final fix = await LocationService().current();
      if (!mounted) return;
      final destination = stageEntryPoint(
        LatLng(fix.latitude, fix.longitude),
        start,
        widget.route.segments
            .expand((segment) => segment)
            .map((p) => p.position),
      );
      if (destination == null) {
        throw StateError('No usable stage coordinates available.');
      }
      await open(destination);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: busy || (start == null && widget.route.segments.isEmpty)
            ? null
            : locateAndOpen,
        icon: const Icon(Icons.directions_walk),
        label: Text(
          busy ? 'Finding your location…' : 'Join this stage with Google Maps',
        ),
      ),
      const Text(
        'Uses your location to choose the stage start or a closer recorded track point by straight-line distance. Google Maps plans the walking route.',
      ),
      if (start != null)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    await open(start!);
                  } catch (error) {
                    if (context.mounted) showFailure(context, error);
                  }
                },
          child: const Text('Navigate to stage start instead'),
        ),
    ],
  );
}
