import 'location_facility_map_layer.dart';
import 'screens.dart' show LocationDetailScreen;
import 'stage_list_screen.dart';
import 'camino_colors.dart';
import 'accommodation_map_layer.dart';
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
import '../data/models.dart' hide Row;
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
  final panelController = DraggableScrollableController();
  double panelExtent = .26;
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
    panelController.dispose();
    mapController.dispose();
    super.dispose();
  }

  String distance(double meters) => '${(meters / 1000).toStringAsFixed(1)} km';
  String guidanceDistance(double? metres) =>
      metres == null ? 'Distance unavailable' : distance(metres);
  String time(Duration? duration) => navigationTime(duration);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.stage.name),
      centerTitle: true,
      actions: [
        MapFacilityFilter(settings: widget.settings),
        IconButton(
          tooltip: 'Change stage',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StageListScreen(
                repository: widget.repository,
                settings: widget.settings,
                mapMode: true,
              ),
            ),
          ),
        ),
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
      retry: () => widget.repository.route(widget.stage),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: viewCoordinates.isEmpty
                            ? const Center(
                                child: Text('No coordinates available.'),
                              )
                            : FlutterMap(
                                mapController: mapController,
                                options: MapOptions(
                                  onMapReady: () =>
                                      setState(() => mapReady = true),
                                  initialCenter: viewCoordinates.first,
                                  initialZoom: 13,
                                  initialCameraFit: viewCoordinates.length > 1
                                      ? CameraFit.bounds(
                                          bounds: LatLngBounds.fromPoints(
                                            viewCoordinates,
                                          ),
                                          padding: EdgeInsets.fromLTRB(
                                            32,
                                            32,
                                            32,
                                            constraints.maxHeight * .26 + 32,
                                          ),
                                          maxZoom: 16,
                                        )
                                      : null,
                                  backgroundColor: const Color(0xFFE6EBDF),
                                ),
                                children: [
                                  if (widget.showOfflineMap)
                                    const OfflineBasemap(),
                                  PolylineLayer(
                                    polylines: [
                                      if (route.canGuide)
                                        Polyline(
                                          points: route.points
                                              .map((p) => p.position)
                                              .toList(),
                                          strokeWidth: 5,
                                          borderStrokeWidth: 2,
                                          borderColor: CaminoColors.of(
                                            context,
                                          ).routeCasing,
                                          color: CaminoColors.of(
                                            context,
                                          ).routeLine,
                                        )
                                      else
                                        for (final segment in route.segments)
                                          Polyline(
                                            points: segment
                                                .map((p) => p.position)
                                                .toList(),
                                            strokeWidth: 4,
                                            color: CaminoColors.of(
                                              context,
                                            ).gpsStale,
                                          ),
                                    ],
                                  ),
                                  if (widget.showOfflineMap)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              constraints.maxHeight *
                                              panelExtent,
                                        ),
                                        child: ColoredBox(
                                          color: Colors.white,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.black87,
                                              minimumSize: const Size(48, 32),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
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
                                              '\u00a9 OpenStreetMap contributors · OpenMapTiles',
                                              style: TextStyle(fontSize: 9),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  AccommodationMapLayer(
                                    repository: widget.repository,
                                  ),
                                  LocationFacilityMapLayer(
                                    locations: route.locations,
                                    settings: widget.settings,
                                    onTap: (location) => navigate(
                                      context,
                                      LocationDetailScreen(
                                        repository: widget.repository,
                                        location: location,
                                      ),
                                    ),
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      if (result != null)
                                        Marker(
                                          point: result.nearestPosition,
                                          width: 20,
                                          height: 20,
                                          child: Icon(
                                            Icons.circle_outlined,
                                            color: CaminoColors.of(
                                              context,
                                            ).routeLine,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  CompassLayer(
                                    position: position,
                                    walkingControls: true,
                                    verticalControls: true,
                                    controlsBottomInset:
                                        constraints.maxHeight * panelExtent,
                                    controlsVisible: panelExtent < .6,
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
                      NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          setState(() => panelExtent = notification.extent);
                          return false;
                        },
                        child: DraggableScrollableSheet(
                          controller: panelController,
                          initialChildSize: .26,
                          minChildSize: .26,
                          maxChildSize: .92,
                          snap: true,
                          snapSizes: const [.26, .62, .92],
                          builder: (context, scrollController) => Material(
                            elevation: 12,
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              children: [
                                Center(
                                  child: IconButton(
                                    tooltip: panelExtent < .6
                                        ? 'Expand guidance'
                                        : 'Collapse guidance',
                                    icon: Icon(
                                      panelExtent < .6
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                    ),
                                    onPressed: () => panelController.animateTo(
                                      panelExtent < .6 ? .92 : .26,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                                Text(
                                  'NEXT',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: CaminoColors.of(
                                          context,
                                        ).nextWaypoint,
                                        letterSpacing: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                LayoutBuilder(
                                  builder: (context, bounds) {
                                    final name = Text(
                                      result == null
                                          ? 'Stage ${widget.stage.displayNumber}'
                                          : result.nextWaypoint?.waypointName ??
                                                'End of route',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    );
                                    final metrics = result == null
                                        ? const Text('Update your position')
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                guidanceDistance(
                                                  result.distanceToNextMeters,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(time(result.timeToNext)),
                                            ],
                                          );
                                    return MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(16) >
                                                24 ||
                                            bounds.maxWidth < 300
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [name, metrics],
                                          )
                                        : Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: name),
                                              const SizedBox(width: 16),
                                              metrics,
                                            ],
                                          );
                                  },
                                ),
                                if (result != null) ...[
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final total = guidance
                                          .calculate(
                                            route.points,
                                            route.points.first.position,
                                            widget.settings.paceKmh,
                                          )
                                          ?.remainingMeters;
                                      return total == null ||
                                              total <= 0 ||
                                              result.remainingMeters == null
                                          ? const SizedBox.shrink()
                                          : LinearProgressIndicator(
                                              value:
                                                  ((total - result.remainingMeters!) /
                                                          total)
                                                      .clamp(0, 1),
                                              semanticsLabel:
                                                  'Position along stage',
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${guidanceDistance(result.remainingMeters)} · ${time(result.timeRemaining)} to stage end',
                                  ),
                                ],
                                if (result != null &&
                                    result.offRouteMeters >
                                        widget.settings.offRouteMetres)
                                  Text(
                                    'Off route: ${result.offRouteMeters.round()} m from the trail',
                                    style: TextStyle(
                                      color: CaminoColors.of(context).offRoute,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (coordinates.isEmpty)
                                  const Text(
                                    'Location markers only: no track geometry has been imported for this stage.',
                                  ),
                                PositionControls(
                                  compact: true,
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

                                if (result == null && route.canGuide)
                                  const Text(
                                    'Update your position for stage guidance.',
                                  ),
                                if (!route.canGuide) ...[
                                  const Text('Full-stage guidance unavailable'),
                                  for (final issue in route.issues) Text(issue),
                                ],
                                if (result != null)
                                  ExpansionTile(
                                    title: const Text('Route details'),
                                    children: [
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                      await SafeLinks.open(
                                        'https://www.openmaptiles.org/',
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        showFailure(context, error);
                                      }
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
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    ),
  );
}
