import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import 'screens.dart' show LocationDetailScreen;
import 'widgets.dart';

class LocationLinks extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  const LocationLinks({
    super.key,
    required this.repository,
    required this.location,
  });

  @override
  State<LocationLinks> createState() => _LocationLinksState();
}

class _LocationLinksState extends State<LocationLinks> {
  late Future<List<(String, Location, IconData)>> future = load();

  Future<List<(String, Location, IconData)>> load() async {
    final location = widget.location;
    final links = [
      ('Prior location', location.priorLocationId, Icons.arrow_back),
      (
        'Alternate prior location',
        location.alternativePriorLocationId,
        Icons.alt_route,
      ),
      ('Next location', location.nextLocationId, Icons.arrow_forward),
      (
        'Alternate next location',
        location.alternativeNextLocationId,
        Icons.alt_route,
      ),
    ];
    final ids = links
        .map((link) => link.$2)
        .whereType<int>()
        .where((id) => id > 0 && id != location.id)
        .toSet();
    final places = await widget.repository.locationsByIds(ids);
    return [
      for (final link in links)
        if (places[link.$2] case final Location place)
          (link.$1, place, link.$3),
    ];
  }

  @override
  void didUpdateWidget(covariant LocationLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.repository != widget.repository) {
      future = load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(() => future = load()),
          child: const Text('Retry location links'),
        );
      }
      final links = snapshot.data ?? [];
      if (links.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final link in links)
              TextButton.icon(
                icon: Icon(link.$3),
                label: Text('${link.$1}: ${link.$2.name}'),
                onPressed: () => navigate(
                  context,
                  LocationDetailScreen(
                    repository: widget.repository,
                    location: link.$2,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
