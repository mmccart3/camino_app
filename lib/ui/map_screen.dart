import 'offline_basemap.dart';
import 'walking_alerts.dart';
import '../services/navigation_session.dart';
import '../services/map_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/route_guidance.dart';
import '../services/settings_service.dart';
import '../services/safe_links.dart';
import 'widgets.dart';

class MapScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  final bool initialTiles;
  final bool initialOffline;
  final TileProvider? tileProvider;
  const MapScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
    this.initialTiles = true,
    this.initialOffline = true,
    this.tileProvider,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final future = widget.repository.route(widget.stage);
  final guidance = RouteGuidanceService();
  late bool tiles =
      widget.initialTiles &&
      !widget.initialOffline &&
      MapTiles.blockedStatus == null;
  late bool offline = widget.initialTiles && widget.initialOffline;
  bool handlingTileBlock = false;

  void tileError(Object error) {
    if (error is! NetworkImageLoadException ||
        (error.statusCode != 403 && error.statusCode != 429) ||
        handlingTileBlock) {
      return;
    }
    handlingTileBlock = true;
    MapTiles.blockedStatus = error.statusCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          tiles = false;
        });
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void initState() {
    super.initState();
    NavigationSession.instance.addListener(sessionChanged);
    sessionChanged();
  }

  void sessionChanged() {
    final session = NavigationSession.instance;
    final fix = session.position;
    if (!mounted) return;
    setState(() {
      if (session.active && session.stageId == widget.stage.id && fix != null) {
        position = LatLng(fix.latitude, fix.longitude);
        accuracy = fix.accuracy;
        fixedAt = fix.timestamp;
      }
    });
  }

  @override
  void dispose() {
    NavigationSession.instance.removeListener(sessionChanged);
    super.dispose();
  }

  bool busy = false;
  LatLng? position;
  double? accuracy;
  DateTime? fixedAt;
  Future<void> locate() async {
    setState(() {
      busy = true;
    });
    try {
      final fix = await LocationService().current();
      if (!mounted) {
        return;
      }
      setState(() {
        position = LatLng(fix.latitude, fix.longitude);
        accuracy = fix.accuracy;
        fixedAt = fix.timestamp;
      });
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String distance(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';
  String guidanceDistance(double? metres) =>
      metres == null ? 'Distance unavailable' : distance(metres);
  String time(Duration? duration) => duration == null
      ? 'Time unavailable'
      : '${(duration.inMicroseconds / Duration.microsecondsPerMinute).ceil()} min';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.stage.name)),
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                    height: 340,
                    child: FlutterMap(
                      options: MapOptions(
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
                        // Local vector tiles share the existing camera and route overlays.
                        if (offline) const OfflineBasemap(),
                        if (tiles)
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'CaminoGuideOfflineMVP',
                            tileProvider:
                                widget.tileProvider ?? MapTiles.provider(),
                            panBuffer: 0,
                            maxNativeZoom: 19,
                            errorTileCallback: (_, error, _) =>
                                tileError(error),
                          ),
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
                        if (tiles || offline)
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
                                  '© OpenStreetMap contributors',
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
                            if (position != null)
                              Marker(
                                point: position!,
                                width: 30,
                                height: 30,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
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
                      ],
                    ),
                  ),
                if (coordinates.isEmpty)
                  const Text(
                    'Location markers only: no track geometry has been imported for this stage.',
                  ),
                if (MapTiles.blockedStatus != null)
                  Text(
                    'OpenStreetMap returned HTTP ${MapTiles.blockedStatus}. Online tiles are paused for this app session. Your route and markers remain available. If access remains blocked, contact the tile provider; repeated retries will not resolve a block.',
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offline stages 1–5 map'),
                  subtitle: const Text(
                    'Bundled on this device: stages 1–5, Saint-Jean-Pied-de-Port to Estella. Other stages have no bundled basemap.',
                  ),
                  value: offline,
                  onChanged: (value) => setState(() {
                    offline = value ?? false;
                    if (offline) tiles = false;
                  }),
                ),
                if (offline)
                  TextButton(
                    onPressed: () async {
                      try {
                        await SafeLinks.open('https://www.openmaptiles.org/');
                      } catch (error) {
                        if (context.mounted) showFailure(context, error);
                      }
                    },
                    child: const Text('© OpenMapTiles'),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Online basemap'),
                  subtitle: const Text(
                    'Available routes and markers remain visible without tiles.',
                  ),
                  value: tiles,
                  onChanged: MapTiles.blockedStatus != null
                      ? null
                      : (value) => setState(() {
                          tiles = value;
                          if (tiles) offline = false;
                        }),
                ),
                FilledButton.icon(
                  onPressed:
                      busy ||
                          !route.canGuide ||
                          NavigationSession.instance.active
                      ? null
                      : locate,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    busy ? 'Getting position…' : 'Update my position',
                  ),
                ),
                WalkingAlertControls(route: route, settings: widget.settings),
                const SizedBox(height: 12),
                if (result == null && route.canGuide)
                  const Text(
                    'Tap Update my position for guidance along the whole stage.',
                  )
                else if (result != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next: ${result.nextWaypoint?.waypointName ?? (result.nextWaypoint == null ? 'End of route' : 'Next waypoint')}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${guidanceDistance(result.distanceToNextMeters)} · ${time(result.timeToNext)} to next waypoint',
                          ),
                          Text(
                            '${guidanceDistance(result.remainingMeters)} · ${time(result.timeRemaining)} to stage end',
                          ),
                          Text(
                            'Walking pace: ${widget.settings.paceKmh.toStringAsFixed(1)} km/h',
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
                            'Times use weighted route distances and your saved pace; they exclude breaks and the walk back to the track point.',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
