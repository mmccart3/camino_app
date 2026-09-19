import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/ahead_of_me.dart';
import '../services/location_service.dart';
import '../services/route_guidance.dart';
import '../services/settings_service.dart';
import 'screens.dart' show LocationDetailScreen, ExternalLinkButton;
import 'widgets.dart';

class AheadStagePicker extends StatelessWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  late final Future<List<Stage>> stages = repository.stages();
  AheadStagePicker({
    super.key,
    required this.repository,
    required this.settings,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ahead of me — choose a stage')),
    body: DataView(
      future: stages,
      builder: (items) => ListView(
        children: [
          for (final stage in items)
            ListTile(
              title: Text(stage.name),
              leading: CircleAvatar(child: Text('${stage.id}')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigate(
                context,
                AheadScreen(
                  repository: repository,
                  settings: settings,
                  stage: stage,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AheadScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  const AheadScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
  });
  @override
  State<AheadScreen> createState() => _AheadScreenState();
}

class _AheadScreenState extends State<AheadScreen> {
  late final routeFuture = widget.repository.route(widget.stage);
  LatLng? position;
  DateTime? fixedAt;
  bool busy = false, preview = false;
  String? error;
  String filter = 'All';

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
      preview = false;
      position = null;
    });
    try {
      final fix = await LocationService().current();
      if (!mounted) return;
      if (!fix.accuracy.isFinite || fix.accuracy < 0 || fix.accuracy > 50) {
        throw StateError(
          'GPS accuracy is too low. Please try Update position again.',
        );
      }
      if (DateTime.now().difference(fix.timestamp).inSeconds.abs() > 120) {
        throw StateError('The location fix is too old. Please try again.');
      }
      setState(() {
        position = LatLng(fix.latitude, fix.longitude);
        fixedAt = fix.timestamp;
      });
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ahead of me')),
    body: DataView(
      future: routeFuture,
      builder: (route) => ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          final guidance = position == null || !route.canGuide
              ? null
              : RouteGuidanceService().calculate(
                  route.points,
                  position!,
                  widget.settings.paceKmh,
                );
          final tooFar = guidance != null && guidance.offRouteMeters > 150;
          final index = preview
              ? 0
              : guidance == null || tooFar
              ? null
              : route.points.indexWhere(
                  (p) => p.id == guidance.nearestTrackPoint.id,
                );
          final all = index == null
              ? <AheadPlace>[]
              : AheadOfMeService().calculate(
                  route,
                  index,
                  widget.settings.paceKmh,
                );
          final visible = all
              .where(
                (p) => switch (filter) {
                  'Café' => p.location.hasBarCafe == true,
                  'Pharmacy' => p.location.hasPharmacy == true,
                  'Groceries' => p.location.hasGroceryStore == true,
                  _ => true,
                },
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.stage.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Upcoming places on this stage, in walking order.'),
              if (!route.canGuide) ...[
                const SizedBox(height: 16),
                const Text(
                  'Ahead-of-me estimates are unavailable until this stage’s navigation tracks are complete and validated.',
                ),
                for (final issue in route.issues) Text(issue),
              ] else ...[
                FilledButton.icon(
                  onPressed: busy ? null : locate,
                  icon: const Icon(Icons.my_location),
                  label: Text(busy ? 'Finding position…' : 'Update position'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          preview = true;
                          position = null;
                          error = null;
                        }),
                  child: const Text('Preview from stage start'),
                ),
                if (error != null) Text(error!),
                if (tooFar)
                  const Text(
                    'You are more than 150 m from this stage’s recorded track. Choose the correct stage or move closer before requesting estimates.',
                  ),
                if (index == null && error == null && !tooFar)
                  const Text(
                    'Update your position, or preview the places ahead from the stage start.',
                  ),
                if (index != null) ...[
                  Text(
                    preview
                        ? 'Preview from the first recorded track point.'
                        : 'From your position recorded at ${TimeOfDay.fromDateTime(fixedAt!.toLocal()).format(context)}. Tap Update position as you walk.',
                  ),
                  Text(
                    'Walking pace: ${widget.settings.paceKmh.toStringAsFixed(1)} km/h. Times exclude stops.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in [
                        'All',
                        'Café',
                        'Pharmacy',
                        'Groceries',
                      ])
                        ChoiceChip(
                          label: Text(value),
                          selected: filter == value,
                          onSelected: (_) => setState(() => filter = value),
                        ),
                    ],
                  ),
                  if (all.isEmpty)
                    const Text('No further places remain on this stage.')
                  else if (visible.isEmpty)
                    const Text(
                      'No matching services are recorded ahead on this stage.',
                    ),
                  for (final place in visible)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(place.location.name),
                              subtitle: Text(
                                '${place.metres == null ? 'Distance unavailable' : '${(place.metres! / 1000).toStringAsFixed(2)} km'} · ${place.walkingTime == null ? 'Time unavailable' : '${(place.walkingTime!.inMicroseconds / Duration.microsecondsPerMinute).ceil()} min'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => navigate(
                                context,
                                LocationDetailScreen(
                                  repository: widget.repository,
                                  location: place.location,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                if (place.location.hasBarCafe == true)
                                  const _ServiceIcon(
                                    Icons.local_cafe_outlined,
                                    'Bar / café',
                                  ),
                                if (place.location.hasPharmacy == true)
                                  const _ServiceIcon(
                                    Icons.local_pharmacy_outlined,
                                    'Pharmacy',
                                  ),
                                if (place.location.hasGroceryStore == true)
                                  const _ServiceIcon(
                                    Icons.shopping_basket_outlined,
                                    'Groceries',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visible.any(
                    (p) =>
                        [
                          'hasBarCafeSource',
                          'hasPharmacySource',
                          'hasGroceryStoreSource',
                        ].any(
                          (key) => (text(p.location.source, key) ?? '')
                              .startsWith('OSM reviewed:'),
                        ),
                  ))
                    const ExternalLinkButton(
                      url: 'https://www.openstreetmap.org/copyright',
                      label: '© OpenStreetMap contributors',
                    ),
                  const Text(
                    'Distances and times end at the recorded location waypoint, not the door of a business. This view stops at the stage end.',
                  ),
                ],
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _ServiceIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ServiceIcon(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 32),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
