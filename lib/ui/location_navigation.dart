import 'navigation_summary.dart';
import 'position_controls.dart';
import 'compass_layer.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../data/route_assembler.dart';
import '../services/location_route.dart';
import '../services/location_service.dart';
import '../services/offline_coverage.dart';
import '../services/map_links.dart';
import '../services/route_guidance.dart';
import '../services/settings_service.dart';
import 'offline_basemap.dart';
import 'screens.dart' show ExternalLinkButton;

class LocationNavigationButton extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  final Future<bool> Function(List<LatLng>)? coverageCheck;
  const LocationNavigationButton({
    super.key,
    required this.repository,
    required this.location,
    this.coverageCheck,
  });
  @override
  State<LocationNavigationButton> createState() =>
      _LocationNavigationButtonState();
}

class _LocationNavigationButtonState extends State<LocationNavigationButton> {
  bool busy = false;
  String? reason;
  Future<bool> covers(List<LatLng> points) =>
      (widget.coverageCheck ?? OfflineCoverage.covers)(points);
  Future<void> navigate() async {
    setState(() {
      busy = true;
      reason = null;
    });
    try {
      final destination = widget.location.position;
      if (MapLinks.walkingDirections(destination) == null) {
        setState(() => reason = 'This location has no usable GPS coordinates.');
        return;
      }
      if (!await covers([destination!])) {
        if (mounted) {
          setState(
            () => reason = 'This location is outside your downloaded map area.',
          );
        }
        return;
      }
      final fix = await LocationService().current();
      final position = LatLng(fix.latitude, fix.longitude);
      final routes = <StageRoute>[];
      for (final stage in await widget.repository.stages()) {
        routes.add(await widget.repository.route(stage));
      }
      final route = LocationRoutePlanner.plan(
        routes,
        widget.location,
        position,
      );
      if (!mounted) return;
      if (route == null) {
        setState(
          () => reason =
              'No connected offline track is available from your nearest track point to this location, or you are more than 150 m from the recorded track.',
        );
        return;
      }
      if (!await covers([
        position,
        ...route.points.map((p) => p.position),
        destination,
      ])) {
        if (mounted) {
          setState(
            () => reason =
                'Part of the route is outside your downloaded map area.',
          );
        }
        return;
      }
      final settings = SettingsService();
      try {
        await settings.load();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LocationNavigationScreen(
              location: widget.location,
              route: route,
              initialPosition: fix,
              settings: settings,
            ),
          ),
        );
      } finally {
        settings.dispose();
      }
    } catch (error) {
      if (mounted) {
        setState(() => reason = 'Offline navigation could not start. $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = MapLinks.walkingDirections(widget.location.position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : navigate,
          icon: const Icon(Icons.navigation),
          label: Text(
            busy ? 'Checking offline route…' : 'Navigate here offline',
          ),
        ),
        if (reason != null) ...[
          Text(reason!),
          if (google != null) ...[
            ExternalLinkButton(url: google, label: 'Navigate with Google Maps'),
            const Text(
              'Google Maps may require an internet connection for walking directions.',
            ),
          ],
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Foreground destination guidance. Pauses refreshes on leaving or locking the screen;
/// existing opt-in screen-locked stage alerts remain a separate session.
class LocationNavigationScreen extends StatefulWidget {
  final Location location;
  final LocationRoute route;
  final Position initialPosition;
  final SettingsService settings;
  const LocationNavigationScreen({
    super.key,
    required this.location,
    required this.route,
    required this.initialPosition,
    required this.settings,
  });
  @override
  State<LocationNavigationScreen> createState() =>
      _LocationNavigationScreenState();
}

class _LocationNavigationScreenState extends State<LocationNavigationScreen> {
  late Position fix = widget.initialPosition;
  final guidance = RouteGuidanceService();
  final mapController = MapController();
  bool mapReady = false;
  Timer? freshnessTimer;
  @override
  void initState() {
    super.initState();
    freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  void updatePosition(Position value) {
    if (!mounted) return;
    setState(() => fix = value);
    if (mapReady && widget.settings.followPosition) {
      mapController.move(
        LatLng(value.latitude, value.longitude),
        mapController.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    freshnessTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  String metres(double? value) => value == null
      ? 'Distance unavailable'
      : '${(value / 1000).toStringAsFixed(2)} km';
  String minutes(Duration? value) => navigationTime(value);
  @override
  Widget build(BuildContext context) {
    final position = LatLng(fix.latitude, fix.longitude);
    final coordinates = widget.route.points.map((p) => p.position).toList();
    final result = guidance.calculate(
      widget.route.points,
      position,
      widget.settings.paceKmh,
    )!;
    final stale =
        DateTime.now().difference(fix.timestamp) > const Duration(seconds: 30);
    final arrived =
        !stale &&
        fix.accuracy <= 50 &&
        const Distance()(position, widget.location.position!) <= 30;
    return Scaffold(
      appBar: AppBar(
        title: Text('To ${widget.location.name}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: navigationMapHeight(context),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    onMapReady: () => mapReady = true,
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([
                        ...coordinates,
                        widget.location.position!,
                      ]),
                      padding: const EdgeInsets.all(30),
                      maxZoom: 16,
                    ),
                  ),
                  children: [
                    const OfflineBasemap(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: coordinates,
                          strokeWidth: 5,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.location.position!,
                          child: const Icon(Icons.flag, color: Colors.red),
                        ),
                      ],
                    ),
                    CompassLayer(position: position),
                  ],
                ),
              ),
              NavigationSummary(
                title: arrived
                    ? 'You are near ${widget.location.name}'
                    : 'Next: ${result.nextWaypoint?.waypointName ?? (result.nextWaypoint == null ? widget.location.name : "Next waypoint")}',
                distance: metres(result.distanceToNextMeters),
                time: minutes(result.timeToNext),
                remaining:
                    '${metres(result.remainingMeters)} / ${minutes(result.timeRemaining)} to ${widget.location.name}',
                warning: result.offRouteMeters > widget.settings.offRouteMetres
                    ? 'You are away from the recorded track.'
                    : null,
              ),
              PositionControls(
                settings: widget.settings,
                onPosition: updatePosition,
                initialTimestamp: widget.initialPosition.timestamp,
              ),
              if (stale)
                const Text(
                  'This is a recorded position, not a live fix. Update to check arrival.',
                ),
              if (fix.accuracy > 50)
                const Text(
                  'GPS accuracy is poor; distance and arrival estimates may be unreliable.',
                ),
              ExpansionTile(
                title: const Text('Route details'),
                children: [
                  Text(
                    'Flat-ground walking speed: ${widget.settings.paceKmh.toStringAsFixed(1)} km/h',
                  ),
                  Text(
                    '${result.offRouteMeters.round()} m from nearest track point · GPS accuracy ±${fix.accuracy.round()} m',
                  ),
                  if (result.offRouteMeters > widget.settings.offRouteMetres)
                    const Text(
                      'You are away from the recorded track. Return to the track or use Google Maps.',
                    ),
                  Text(
                    'The track ends ${widget.route.destinationOffset.round()} m from the location pin. Estimates exclude the walk to and from the track and breaks. Follow local signs for the final approach.',
                  ),
                  if (widget.route.reversed)
                    const Text(
                      'Reverse travel uses the stored walking weights; uphill/downhill times may differ.',
                    ),
                  const Text(
                    'Enable automatic updates or update manually. Automatic position updates pause when this map is hidden or the screen is locked.',
                  ),
                ],
              ),
              ExternalLinkButton(
                url: MapLinks.walkingDirections(widget.location.position)!,
                label: 'Navigate with Google Maps',
              ),
              const ExternalLinkButton(
                url: 'https://www.openstreetmap.org/copyright',
                label: '\u00a9 OpenStreetMap contributors',
                fontSize: 11,
              ),
              const ExternalLinkButton(
                url: 'https://www.openmaptiles.org/',
                label: '\u00a9 OpenMapTiles',
                fontSize: 11,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
