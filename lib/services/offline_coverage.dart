import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';
import 'offline_map.dart';

/// Tests actual detailed tile presence, not the archive's broad bounding box.
class OfflineCoverage {
  static Future<bool> covers(List<LatLng> points, {String? path}) async {
    final provider = await MbTilesVectorTileProvider.open(
      path ?? await OfflineMap.installedPath(),
    );
    try {
      final zoom = provider.maximumZoom;
      final n = 1 << zoom;
      final checked = <String>{};
      for (var i = 0; i < points.length; i++) {
        final a = i == 0 ? points[i] : points[i - 1], b = points[i];
        final steps = math.max(1, (const Distance()(a, b) / 25).ceil());
        for (var j = 0; j <= steps; j++) {
          final lat = a.latitude + (b.latitude - a.latitude) * j / steps;
          final lon = a.longitude + (b.longitude - a.longitude) * j / steps;
          if (!lat.isFinite ||
              !lon.isFinite ||
              lat.abs() > 85.0511 ||
              lon.abs() >= 180) {
            return false;
          }
          final radians = lat * math.pi / 180;
          final x = ((lon + 180) / 360 * n).floor();
          final y =
              ((1 -
                          math.log(math.tan(radians) + 1 / math.cos(radians)) /
                              math.pi) /
                      2 *
                      n)
                  .floor();
          if (checked.add('$x/$y') &&
              await provider.load(vt.TileKey(zoom, x, y))
                  is! vt.TileResponseData) {
            return false;
          }
        }
      }
      return points.isNotEmpty;
    } finally {
      provider.dispose();
    }
  }
}
