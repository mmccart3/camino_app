import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../services/settings_service.dart';
import '../services/location_service.dart';
import '../services/route_guidance.dart';
import 'navigation_summary.dart';

/// An explicit foreground position check; this never starts tracking.
class TodayProgress extends StatefulWidget {
  final Stage stage;
  final CaminoRepository repository;
  final SettingsService settings;
  const TodayProgress({
    super.key,
    required this.stage,
    required this.repository,
    required this.settings,
  });
  @override
  State<TodayProgress> createState() => _TodayProgressState();
}

class _TodayProgressState extends State<TodayProgress> {
  bool busy = false;
  String? message;
  RouteGuidance? guidance;
  DateTime? checked;
  Future<void> update() async {
    setState(() {
      busy = true;
      guidance = null;
      message = null;
    });
    try {
      final route = await widget.repository.route(widget.stage);
      if (!route.canGuide) {
        throw StateError('Guidance is not available for this stage yet.');
      }
      final fix = await LocationService().current();
      if (!fix.accuracy.isFinite || fix.accuracy > 50) {
        throw StateError(
          'Position is not accurate enough yet. Try again outdoors.',
        );
      }
      final result = RouteGuidanceService().calculate(
        route.points,
        LatLng(fix.latitude, fix.longitude),
        widget.settings.paceKmh,
      );
      if (result == null || result.offRouteMeters > 150) {
        throw StateError(
          'You are away from this stage. Choose the stage you are walking.',
        );
      }
      if (mounted) {
        setState(() {
          guidance = result;
          checked = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = e is StateError
              ? e.message.toString()
              : 'Unable to get your position. Check location access and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String distance(double? metres) => metres == null
      ? 'Unavailable'
      : '${(metres / 1000).toStringAsFixed(1)} km';
  @override
  Widget build(BuildContext context) {
    final g = guidance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (g != null)
          NavigationSummary(
            title: g.nextWaypoint?.waypointName ?? 'Stage end',
            distance: distance(g.distanceToNextMeters),
            time: navigationTime(g.timeToNext),
            remaining:
                'Stage remaining: ${distance(g.remainingMeters)} / ${navigationTime(g.timeRemaining)}',
            status:
                'Position checked at ${TimeOfDay.fromDateTime(checked!).format(context)}. Tap below to refresh.',
          ),
        if (message != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(message!)),
        TextButton.icon(
          onPressed: busy ? null : update,
          icon: const Icon(Icons.my_location),
          label: Text(
            busy ? 'Checking position…' : 'Check next stop & remaining walk',
          ),
        ),
      ],
    );
  }
}
