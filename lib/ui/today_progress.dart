import '../services/walking_day.dart';
import '../services/walking_day_store.dart';
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
  final Stage? stage;
  final SavedWalkingDay? plannedDay;
  final CaminoRepository repository;
  final SettingsService settings;
  const TodayProgress({
    super.key,
    this.stage,
    this.plannedDay,
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
  String destination = '';
  double joins = 0;
  Future<void> update() async {
    setState(() {
      busy = true;
      guidance = null;
      message = null;
    });
    try {
      List<TrackPoint> points;
      final saved = widget.plannedDay;
      if (saved != null) {
        final planner = await WalkingDayPlanner.load(widget.repository);
        final day = planner.calculate(saved.pathIds, widget.settings.paceKmh);
        points = day.guidancePoints;
        destination = day.places.last.name;
        joins = day.joinMetres;
      } else {
        final stage = widget.stage;
        if (stage == null) {
          throw StateError('Choose a stage to check your progress.');
        }
        final route = await widget.repository.route(stage);
        if (!route.canGuide) {
          throw StateError('Guidance is not available for this stage yet.');
        }
        points = route.points;
        destination = 'stage end';
        joins = 0;
      }
      if (!mounted) return;
      final fix = await LocationService().current();
      if (!fix.accuracy.isFinite ||
          fix.accuracy < 0 ||
          fix.accuracy > 50 ||
          DateTime.now().difference(fix.timestamp).inSeconds.abs() > 120) {
        throw StateError(
          'Position is not accurate enough yet. Try again outdoors.',
        );
      }
      final result = RouteGuidanceService().calculate(
        points,
        LatLng(fix.latitude, fix.longitude),
        widget.settings.paceKmh,
      );
      if (result == null || result.offRouteMeters > 150) {
        throw StateError(
          'You are more than 150 m from the selected route. Check your planned day or current stage.',
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
            title: g.nextWaypoint?.waypointName ?? destination,
            distance: distance(g.distanceToNextMeters),
            time: navigationTime(g.timeToNext),
            remaining:
                '${widget.plannedDay == null ? "Stage remaining" : "To $destination"}: ${distance(g.remainingMeters)} / ${navigationTime(g.timeRemaining)}',
            warning: joins > 0
                ? 'Recorded walking segments only; ${joins.round()} m of joins have no walking-time estimate.'
                : null,
            status:
                'Position checked at ${TimeOfDay.fromDateTime(checked!).format(context)}. Tap below to refresh.',
          ),
        if (widget.plannedDay != null)
          const Text('Today’s planned route: walking time excludes breaks'),
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
