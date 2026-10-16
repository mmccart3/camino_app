import 'camino_colors.dart';
import 'dart:async';
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
  final ValueChanged<LatLng>? onPosition;
  final SavedWalkingDay? plannedDay;
  final CaminoRepository repository;
  final SettingsService settings;
  const TodayProgress({
    super.key,
    this.stage,
    this.onPosition,
    this.plannedDay,
    required this.repository,
    required this.settings,
  });
  @override
  State<TodayProgress> createState() => _TodayProgressState();
}

class _TodayProgressState extends State<TodayProgress> {
  Timer? ageTimer;
  @override
  void initState() {
    super.initState();
    ageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && checked != null) setState(() {});
    });
  }

  @override
  void dispose() {
    ageTimer?.cancel();
    super.dispose();
  }

  String compactTime(Duration? value) => navigationTime(value);
  bool busy = false;
  String? message;
  RouteGuidance? guidance;
  DateTime? checked;
  String destination = '';
  double joins = 0;
  double? totalMetres;
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
      totalMetres = RouteGuidanceService()
          .calculate(points, points.first.position, widget.settings.paceKmh)
          ?.remainingMeters;
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
          checked = fix.timestamp;
        });
        widget.onPosition?.call(LatLng(fix.latitude, fix.longitude));
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
        if (g != null) ...[
          const Divider(height: 24),
          if (totalMetres != null &&
              totalMetres! > 0 &&
              g.remainingMeters != null) ...[
            LinearProgressIndicator(
              value: ((totalMetres! - g.remainingMeters!) / totalMetres!).clamp(
                0,
                1,
              ),
              semanticsLabel: 'Position along route',
            ),
            const SizedBox(height: 8),
            Text(
              '${distance((totalMetres! - g.remainingMeters!).clamp(0, totalMetres!))} from start',
            ),
          ],
          Text(
            'Next: ${g.nextWaypoint?.waypointName ?? destination}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${distance(g.distanceToNextMeters)} · ${compactTime(g.timeToNext)}',
          ),
          Text(
            'Remaining: ${distance(g.remainingMeters)} · ${compactTime(g.timeRemaining)}',
          ),
          if (joins > 0)
            Text('${joins.round()} m of joins have no walking-time estimate.'),
        ],
        if (widget.plannedDay != null)
          const Text('Today’s planned route: walking time excludes breaks'),
        if (message != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(message!)),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.gps_fixed,
                size: 18,
                color:
                    checked != null &&
                        DateTime.now().difference(checked!).inSeconds <= 120
                    ? CaminoColors.of(context).gpsGood
                    : CaminoColors.of(context).gpsStale,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  busy
                      ? 'Updating GPS…'
                      : checked == null
                      ? 'GPS not updated'
                      : 'GPS updated ${DateTime.now().difference(checked!).inMinutes.clamp(0, 99999)} min ago',
                  style: TextStyle(
                    color:
                        checked != null &&
                            DateTime.now().difference(checked!).inSeconds <= 120
                        ? Theme.of(context).colorScheme.onSurface
                        : CaminoColors.of(context).gpsStale,
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : update,
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
