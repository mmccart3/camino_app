import 'elevation_screen.dart';
import '../services/recent_walk.dart';
import 'navigation_summary.dart';
import 'compass_layer.dart';
import 'offline_basemap.dart';
import 'ahead_screen.dart';
import 'walking_alerts.dart';
import 'stage_map_coverage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../data/camino_repository.dart';
import '../data/models.dart';
import 'position_controls.dart';
import 'package:geolocator/geolocator.dart';
import '../services/route_guidance.dart';
import '../services/settings_service.dart';
import '../services/safe_links.dart';
import 'widgets.dart';

class MapScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  final bool showOfflineMap;
  const MapScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
    this.showOfflineMap = true,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    RecentWalk.save(widget.stage.id, map: true).ignore();
  }

  late final future = widget.repository.route(widget.stage);
  final guidance = RouteGuidanceService();
  final mapController = MapController();
  bool mapReady = false;
  LatLng? position;
  double? accuracy;
  DateTime? fixedAt;
  void updatePosition(Position fix) {
    if (!mounted) return;
    setState(() {
      position = LatLng(fix.latitude, fix.longitude);
      accuracy = fix.accuracy;
      fixedAt = fix.timestamp;
    });
    if (mapReady && widget.settings.followPosition) {
      mapController.move(position!, mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  String distance(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';
  String guidanceDistance(double? metres) =>
      metres == null ? 'Distance unavailable' : distance(metres);
  String time(Duration? duration) => navigationTime(duration);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.stage.name),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Ahead of me',
          icon: const Icon(Icons.directions_walk),
          onPressed: () => navigate(
            context,
            AheadScreen(
              repository: widget.repository,
              settings: widget.settings,
              stage: widget.stage,
            ),
          ),
        ),
      ],
    ),
    body: DataView(
      future: future,
      builder: (route) {
        final coordinates = route.segments
            .expand((s) => s.map((p) => p.position))
            .toList();
        final viewCoordinates = coordinates.isNotEmpty
            ? coordinates
            : route.locations
                  .map((l) => l.position)
                  .whereType<LatLng>()
                  .toList();
        return ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            final result = position == null || !route.canGuide
                ? null
                : guidance.calculate(
                    route.points,
                    position!,
                    widget.settings.paceKmh,
                  );
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result != null)
                      NavigationSummary(
                        title:
                            'Next: ${result.nextWaypoint?.waypointName ?? (result.nextWaypoint == null ? "End of route" : "Next waypoint")}',
                        distance: guidanceDistance(result.distanceToNextMeters),
                        time: time(result.timeToNext),
                        remaining:
                            '${guidanceDistance(result.remainingMeters)} / ${time(result.timeRemaining)} to stage end',
                        status: 'On route at last update',
                        warning:
                            result.offRouteMeters >
                                widget.settings.offRouteMetres
                            ? 'Off route: ${result.offRouteMeters.round()} m from the trail'
                            : null,
                      ),
                    if (fixedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Last position: ${TimeOfDay.fromDateTime(fixedAt!.toLocal()).format(context)} · Accuracy ±${accuracy?.round()} m',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    if (result == null && route.canGuide)
                      const Text(
                        'Update your position or enable automatic updates for stage guidance.',
                      ),
                    if (!route.canGuide) ...[
                      Text(
                        'Full-stage guidance unavailable',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final issue in route.issues) Text('• $issue'),
                      const SizedBox(height: 12),
                    ],
                    if (viewCoordinates.isEmpty)
                      const SizedBox(
                        height: 180,
                        child: Center(child: Text('No coordinates available.')),
                      )
                    else
                      SizedBox(
                        height: navigationMapHeight(context),
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            onMapReady: () => setState(() => mapReady = true),
                            initialCenter: viewCoordinates.first,
                            initialZoom: 13,
                            initialCameraFit: viewCoordinates.length > 1
                                ? CameraFit.bounds(
                                    bounds: LatLngBounds.fromPoints(
                                      viewCoordinates,
                                    ),
                                    padding: const EdgeInsets.all(30),
                                    maxZoom: 16,
                                  )
                                : null,
                            backgroundColor: const Color(0xFFE6EBDF),
                          ),
                          children: [
                            if (widget.showOfflineMap) const OfflineBasemap(),
                            PolylineLayer(
                              polylines: [
                                if (route.canGuide)
                                  Polyline(
                                    points: route.points
                                        .map((p) => p.position)
                                        .toList(),
                                    strokeWidth: 5,
                                    color: const Color(0xFF1456A0),
                                  )
                                else
                                  for (final segment in route.segments)
                                    Polyline(
                                      points: segment
                                          .map((p) => p.position)
                                          .toList(),
                                      strokeWidth: 4,
                                      color: Colors.orange,
                                    ),
                              ],
                            ),
                            if (widget.showOfflineMap)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: TextButton(
                                    onPressed: () async {
                                      try {
                                        await SafeLinks.open(
                                          'https://www.openstreetmap.org/copyright',
                                        );
                                      } catch (error) {
                                        if (context.mounted) {
                                          showFailure(context, error);
                                        }
                                      }
                                    },
                                    child: const Text(
                                      '\u00a9 OpenStreetMap contributors',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ),
                            MarkerLayer(
                              markers: [
                                for (final location in route.locations)
                                  if (location.position != null)
                                    Marker(
                                      point: location.position!,
                                      width: 36,
                                      height: 36,
                                      child: Tooltip(
                                        message: location.name,
                                        child: const Icon(
                                          Icons.place,
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                    ),
                                if (result != null)
                                  Marker(
                                    point: result.nearestPosition,
                                    width: 20,
                                    height: 20,
                                    child: const Icon(
                                      Icons.circle_outlined,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                            CompassLayer(
                              position: position,
                              walkingControls: true,
                              onCentre: position == null || !mapReady
                                  ? null
                                  : () => mapController.move(
                                      position!,
                                      mapController.camera.zoom,
                                    ),
                              onElevation: () => navigate(
                                context,
                                ElevationScreen(
                                  repository: widget.repository,
                                  stage: widget.stage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (coordinates.isEmpty)
                      const Text(
                        'Location markers only: no track geometry has been imported for this stage.',
                      ),
                    PositionControls(
                      settings: widget.settings,
                      onPosition: updatePosition,
                      additionalOptions: [
                        WalkingAlertControls(
                          route: route,
                          settings: widget.settings,
                        ),
                        StageMapCoverage(route: route),
                      ],
                    ),
                    if (result != null)
                      ExpansionTile(
                        title: const Text('Route details'),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Flat-ground walking speed: ${widget.settings.paceKmh.toStringAsFixed(1)} km/h',
                                  ),
                                  const Divider(),
                                  Text(
                                    '${result.offRouteMeters.round()} m from nearest track point · GPS accuracy ±${accuracy?.round()} m',
                                  ),
                                  if (result.offRouteMeters > 50)
                                    const Text(
                                      'You are more than 50 m from the nearest stored track point. Estimates exclude the walk to it.',
                                    ),
                                  Text(
                                    'Track point ${result.nearestTrackPoint.id}: ${result.nearestPosition.latitude.toStringAsFixed(5)}, ${result.nearestPosition.longitude.toStringAsFixed(5)}',
                                  ),
                                  Text(
                                    'Position recorded: ${fixedAt?.toLocal().toString().split('.').first}. Tap Update to refresh.',
                                  ),
                                  const Text(
                                    'Times use weighted route distances and your saved flat-ground speed; they exclude breaks and the walk back to the track point.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await SafeLinks.open('https://www.openmaptiles.org/');
                        } catch (error) {
                          if (context.mounted) showFailure(context, error);
                        }
                      },
                      child: const Text(
                        '\u00a9 OpenMapTiles',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
