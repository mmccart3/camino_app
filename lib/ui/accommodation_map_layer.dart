import 'camino_colors.dart';
import 'accommodation_card.dart' show accommodationPrice;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import 'screens.dart' show AccommodationBrowser;

/// Local property markers; grouped at wider zooms so nearby stays remain tappable.
class AccommodationMapLayer extends StatefulWidget {
  final CaminoRepository repository;
  const AccommodationMapLayer({super.key, required this.repository});
  @override
  State<AccommodationMapLayer> createState() => _AccommodationMapLayerState();
}

class _AccommodationMapLayerState extends State<AccommodationMapLayer> {
  late final places = widget.repository.mapAccommodation();

  void open(Accommodation place, List<Accommodation> group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccommodationBrowser(places: group, initial: place),
      ),
    );
  }

  void choose(List<Accommodation> group) {
    if (group.length == 1) {
      open(group.single, group);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => SizedBox(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${group.length} places to stay',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    for (final place in group)
                      ListTile(
                        leading: Icon(
                          place is Albergue ? Icons.bed : Icons.hotel,
                        ),
                        title: Text(place.name),
                        subtitle: Text(
                          place is Albergue
                              ? '${accommodationPrice(place)}${place.numberOfBeds == null ? "" : " / ${place.numberOfBeds} beds"}'
                              : accommodationPrice(place),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          open(place, group);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return FutureBuilder<List<Accommodation>>(
      future: places,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Align(
            alignment: Alignment.topLeft,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('Accommodation markers unavailable'),
              ),
            ),
          );
        }
        final groups = <String, List<Accommodation>>{};
        final scale = 256 * math.pow(2, camera.zoom);
        for (final place in snapshot.data ?? <Accommodation>[]) {
          final point = place.position!;
          if (!camera.visibleBounds.contains(point)) continue;
          final lat = point.latitude.clamp(-85.0511, 85.0511) * math.pi / 180;
          final x = (point.longitude + 180) / 360 * scale;
          final y =
              (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
              2 *
              scale;
          final key = '${(x / 56).floor()}:${(y / 56).floor()}';
          groups.putIfAbsent(key, () => []).add(place);
        }
        return MarkerLayer(
          markers: [
            for (final group in groups.values)
              Marker(
                point: group.first.position!,
                width: 52,
                height: 52,
                rotate: true,
                child: Tooltip(
                  message: group.length == 1
                      ? group.first.name
                      : '${group.length} places to stay',
                  child: Material(
                    elevation: 5,
                    shadowColor: Colors.black54,
                    color: Theme.of(context).colorScheme.surface,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: CaminoColors.of(context).nextWaypoint,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      customBorder: CircleBorder(),
                      onTap: () => choose(group),
                      child: Semantics(
                        button: true,
                        label: group.length == 1
                            ? group.first.name
                            : '${group.length} places to stay',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              group.first is Albergue ? Icons.bed : Icons.hotel,
                              color: CaminoColors.of(context).nextWaypoint,
                              size: 24,
                            ),
                            if (group.length > 1)
                              Text(
                                '${group.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
