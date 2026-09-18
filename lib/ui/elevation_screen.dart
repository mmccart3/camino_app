import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../data/elevation_profile.dart';
import '../data/elevation_repository.dart';
import '../services/location_service.dart';
import 'elevation_chart.dart';
import 'widgets.dart';

class ElevationScreen extends StatefulWidget {
  final CaminoRepository repository;
  final Stage? stage;
  const ElevationScreen({super.key, required this.repository, this.stage});
  @override
  State<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends State<ElevationScreen> {
  late final future = load();
  bool locating = false;
  String? locationStatus;
  ElevationMatch? current;
  int? currentStage;
  ElevationPoint? selected;

  Future<List<ElevationProfile>> load() async {
    final repository = ElevationRepository(widget.repository);
    final stage = widget.stage;
    return stage == null ? repository.all() : [await repository.profile(stage)];
  }

  Future<void> locate(List<ElevationProfile> profiles) async {
    setState(() {
      locating = true;
      current = null;
      currentStage = null;
      locationStatus = null;
    });
    try {
      final fix = await LocationService().current();
      if (!mounted) return;
      final fresh =
          DateTime.now().difference(fix.timestamp).inSeconds.abs() <= 120;
      ElevationMatch? nearest;
      int? stage;
      if (fresh) {
        for (final profile in profiles) {
          final match = profile.nearest(
            LatLng(fix.latitude, fix.longitude),
            accuracy: fix.accuracy,
          );
          if (match != null &&
              (nearest == null ||
                  match.distanceFromRoute < nearest.distanceFromRoute)) {
            nearest = match;
            stage = profile.stage.id;
          }
        }
      }
      setState(() {
        current = nearest;
        currentStage = stage;
        locationStatus = nearest == null
            ? (!fresh
                  ? 'The location fix is too old. Please try again.'
                  : fix.accuracy > 50
                  ? 'GPS accuracy is too low to identify a nearby elevation sample. Please try again.'
                  : 'No elevation sample within 35 m of your position in this view.')
            : 'Route elevation near you: ${nearest.point.elevationMetres.round()} m · stage $stage, path ${nearest.point.pathId}.\nUpdated ${TimeOfDay.fromDateTime(fix.timestamp.toLocal()).format(context)}. Tap Update to refresh.';
      });
    } catch (error) {
      if (mounted) setState(() => locationStatus = error.toString());
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.stage == null
            ? 'Trail elevation'
            : 'Stage ${widget.stage!.id} elevation',
      ),
    ),
    body: DataView(
      future: future,
      builder: (profiles) {
        final available = profiles.where((p) => p.sampleCount > 1).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.stage == null)
              Text(
                '${available.length} of ${profiles.length} stage profiles have samples. Alternative stages are shown separately.',
              ),
            const Text(
              'Charts show sampled sections only. Missing joins and endpoints are excluded from the distance axis.',
            ),
            const SizedBox(height: 12),
            if (available.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: locating ? null : () => locate(profiles),
                icon: const Icon(Icons.my_location),
                label: Text(
                  locating ? 'Finding position…' : 'Update my route elevation',
                ),
              ),
              if (locationStatus != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(locationStatus!),
                ),
            ],
            for (final profile in profiles) ...[
              const SizedBox(height: 20),
              Text(
                '${profile.stage.id}. ${profile.stage.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (profile.sampleCount < 2)
                const Text(
                  'Elevation samples are not available for this stage yet.',
                )
              else ...[
                Text(
                  '${profile.sampleCount} samples · ${(profile.length / 1000).toStringAsFixed(2)} km of sampled sections',
                ),
                const SizedBox(height: 8),
                ElevationChart(
                  profile: profile,
                  current: currentStage == profile.stage.id ? current : null,
                  selected: selected,
                  onSelect: widget.stage == null
                      ? null
                      : (point) => setState(() => selected = point),
                ),
                if (widget.stage == null)
                  TextButton(
                    onPressed: () => navigate(
                      context,
                      ElevationScreen(
                        repository: widget.repository,
                        stage: profile.stage,
                      ),
                    ),
                    child: const Text('Explore this profile'),
                  )
                else ...[
                  const Text(
                    'Tap the chart to inspect an elevation. Pinch to zoom.',
                  ),
                  if (selected != null)
                    Text(
                      'Path ${selected!.pathId} · ${(selected!.distanceMetres / 1000).toStringAsFixed(2)} km from first sample · ${selected!.elevationMetres.round()} m elevation',
                    ),
                  Slider(
                    label: selected == null
                        ? 'First sample'
                        : '${selected!.elevationMetres.round()} m',
                    value: selected == null
                        ? 0
                        : profile.sections
                              .expand((s) => s.points)
                              .toList()
                              .indexOf(selected!)
                              .clamp(0, profile.sampleCount - 1)
                              .toDouble(),
                    min: 0,
                    max: (profile.sampleCount - 1).toDouble(),
                    onChanged: (value) => setState(
                      () => selected = profile.sections
                          .expand((s) => s.points)
                          .elementAt(value.round()),
                    ),
                  ),
                ],
              ],
              if (profile.missingPaths.isNotEmpty && profile.sampleCount > 0)
                Text(
                  'Missing elevation data for paths: ${profile.missingPaths.join(', ')}.',
                ),
              for (final issue in profile.issues) Text(issue),
            ],
          ],
        );
      },
    ),
  );
}
