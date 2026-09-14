import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Versioned app asset; no HTTP requests or tile downloads are involved.
class OfflineMap {
  static const assetPath = 'assets/offline_maps/stages1_5.mbtiles';
  static const fingerprint =
      '1e325973a60161d47ebc7d6c6747413deacc77dd1a1e87f35fe0bef96121b8ae';
  static Future<String>? _copy;

  static Future<String> installedPath() =>
      _copy ??= install().catchError((Object e) {
        _copy = null;
        throw e;
      });

  static Future<String> install({String? directory}) async {
    final folder = Directory(
      directory ??
          p.join((await getApplicationSupportDirectory()).path, 'offline_maps'),
    );
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, 'stages1-5-$fingerprint.mbtiles'));
    if (await file.exists()) return file.path;
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != fingerprint) {
      throw const FormatException('Offline map asset checksum mismatch');
    }
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      final check = await MbTilesVectorTileProvider.open(temp.path);
      check.dispose();
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    return file.path;
  }

  static Future<vt.Style> load({String? path}) async {
    final provider = await MbTilesVectorTileProvider.open(
      path ?? await installedPath(),
    );
    try {
      return await vt.StyleReader(
        uri: 'asset://assets/offline_maps/style.json',
        cache: false,
        resolveProvider: (id) async {
          if (id != 'openmaptiles') {
            throw StateError('Unknown offline source: $id');
          }
          return provider;
        },
      ).read();
    } catch (_) {
      provider.dispose();
      rethrow;
    }
  }
}
