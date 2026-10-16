import 'camino_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/camino_repository.dart';
import '../data/local_database.dart';
import '../data/models.dart';
import '../services/map_links.dart';
import '../services/offline_coverage.dart';
import 'accommodation_map_layer.dart';
import 'location_navigation.dart';
import 'offline_basemap.dart';
import 'screens.dart' show ExternalLinkButton;

/// A non-interactive preview leaves scrolling and detail-page swipes intact.
class PlaceMap extends StatefulWidget {
  final LatLng? position;
  final String name;
  final int locationId;
  final CaminoRepository? repository;
  final Location? location;
  const PlaceMap({
    super.key,
    required this.position,
    required this.name,
    required this.locationId,
    this.repository,
    this.location,
  });
  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class _PlaceMapState extends State<PlaceMap> {
  LocalDatabase? ownedDatabase;
  late final repository =
      widget.repository ?? CaminoRepository(ownedDatabase = LocalDatabase());
  late final coverage = OfflineCoverage.covers([widget.position!]);
  late final lines = loadLines();

  Future<List<List<LatLng>>> loadLines() async {
    final db = await repository.local.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT s.* FROM stages s JOIN paths p ON p.stageID = s.ID '
      'WHERE p.originLoc = ? OR p.destinationLoc = ?',
      [widget.locationId, widget.locationId],
    );
    final result = <List<LatLng>>[];
    for (final row in rows) {
      final route = await repository.route(Stage.fromRow(row));
      result.addAll(
        route.segments.map(
          (segment) => segment.map((point) => point.position).toList(),
        ),
      );
    }
    return result;
  }

  @override
  void dispose() {
    // Await outstanding reads before closing the database owned by this preview.
    if (ownedDatabase != null) {
      lines.whenComplete(() => ownedDatabase!.close()).ignore();
    }
    super.dispose();
  }

  Widget canvas({required bool expanded}) => FlutterMap(
    options: MapOptions(
      initialCenter: widget.position!,
      initialZoom: 15,
      interactionOptions: InteractionOptions(
        flags: expanded ? InteractiveFlag.all : InteractiveFlag.none,
      ),
    ),
    children: [
      const OfflineBasemap(),
      FutureBuilder<List<List<LatLng>>>(
        future: lines,
        builder: (context, data) => PolylineLayer(
          polylines: [
            for (final line in data.data ?? <List<LatLng>>[])
              Polyline(
                points: line,
                strokeWidth: 4,
                color: CaminoColors.of(context).routeLine,
              ),
          ],
        ),
      ),
      AccommodationMapLayer(repository: repository),
      MarkerLayer(
        markers: [
          Marker(
            point: widget.position!,
            width: 48,
            height: 48,
            child: Tooltip(
              message: widget.name,
              child: Icon(
                Icons.location_pin,
                size: 46,
                color: CaminoColors.of(context).nextWaypoint,
              ),
            ),
          ),
        ],
      ),
      const Align(
        alignment: Alignment.bottomLeft,
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(3),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
        ),
      ),
    ],
  );

  void expand() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(widget.name), centerTitle: true),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: canvas(expanded: true)),
              if (widget.location != null)
                LocationNavigationButton(
                  repository: repository,
                  location: widget.location!,
                )
              else
                ExternalLinkButton(
                  url: MapLinks.walkingDirections(widget.position)!,
                  label: 'Walk here with Google Maps',
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (MapLinks.walkingDirections(widget.position) == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Map unavailable: coordinates not listed.'),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<bool>(
        future: coverage,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data != true) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.hasError
                        ? 'Offline map could not be opened.'
                        : 'Offline map unavailable here',
                  ),
                  ExternalLinkButton(
                    url: MapLinks.walkingDirections(widget.position)!,
                    label: 'Open Google Maps',
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Semantics(
                button: true,
                label: 'Open offline map of ${widget.name}',
                child: GestureDetector(
                  onTap: expand,
                  child: AbsorbPointer(
                    child: SizedBox(
                      height: 220,
                      child: canvas(expanded: false),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: expand,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Explore offline map'),
              ),
            ],
          );
        },
      ),
    );
  }
}
