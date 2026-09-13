import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import '../services/offline_map.dart';

class OfflineBasemap extends StatefulWidget {
  const OfflineBasemap({super.key, this.loadStyle});
  final Future<vt.Style> Function()? loadStyle;
  @override
  State<OfflineBasemap> createState() => _OfflineBasemapState();
}

class _OfflineBasemapState extends State<OfflineBasemap> {
  late Future<vt.Style> future = (widget.loadStyle ?? OfflineMap.load)();
  @override
  void dispose() {
    future.then((style) => style.dispose()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<vt.Style>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Align(
          alignment: Alignment.topCenter,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Offline map could not be opened. Routes remain available.',
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      future = (widget.loadStyle ?? OfflineMap.load)();
                    }),
                    child: const Text('Retry offline map'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final style = snapshot.data;
      if (style == null) {
        return const Align(
          alignment: Alignment.topCenter,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text('Opening offline map…'),
            ),
          ),
        );
      }
      return vt.VectorTileLayer(
        theme: style.theme,
        tileProviders: style.providers,
        diskCacheMaximumSizeInBytes: 0,
        concurrency: 2,
        tileFadeDuration: Duration.zero,
        labelFadeDuration: const Duration(milliseconds: 150),
      );
    },
  );
}
