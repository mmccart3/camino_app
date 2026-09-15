import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_assembler.dart';
import '../services/offline_coverage.dart';
import 'stage_directions.dart';

/// Missing local tiles never trigger an online tile request.
class StageMapCoverage extends StatefulWidget {
  final StageRoute route;
  final Future<bool> Function(List<LatLng>)? coverageCheck;
  const StageMapCoverage({super.key, required this.route, this.coverageCheck});
  @override
  State<StageMapCoverage> createState() => _StageMapCoverageState();
}

class _StageMapCoverageState extends State<StageMapCoverage> {
  late final coverage = check();
  Future<bool> check() async {
    final covers = widget.coverageCheck ?? OfflineCoverage.covers;
    final segments = widget.route.segments;
    // Check each segment separately: never infer lines between broken tracks.
    if (segments.isNotEmpty) {
      for (final segment in segments) {
        if (!await covers(segment.map((p) => p.position).toList())) {
          return false;
        }
      }
    }
    final locations = widget.route.locations
        .map((l) => l.position)
        .whereType<LatLng>();
    for (final location in locations) {
      if (!await covers([location])) return false;
    }
    return segments.isNotEmpty || locations.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: coverage,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Text('Checking offline map coverage…');
      }
      if (snapshot.data == true) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.hasError
                ? 'The offline map could not be checked. Google Maps is available instead.'
                : 'This stage is outside or partly outside your downloaded map area. Use Google Maps for online walking directions.',
          ),
          StageDirections(route: widget.route),
          const Text('Google Maps may need an internet connection.'),
        ],
      );
    },
  );
}
