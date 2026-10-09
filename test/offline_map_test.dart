import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/services/offline_coverage.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:camino_app/services/offline_map.dart';
import 'package:camino_app/ui/offline_basemap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stage 20 is covered along its full recorded route', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      File('assets/database/camino.sqlite').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final rows = await db.rawQuery(
        'SELECT t.latitude,t.longitude FROM track_points t JOIN paths p ON p.pathID=t.pathID WHERE p.stageID=26 ORDER BY t.track_point_id',
      );
      expect(rows.length, 515);
      final points = rows
          .map(
            (r) => LatLng(
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      expect(
        await OfflineCoverage.covers(
          points,
          path: File(OfflineMap.assetPath).absolute.path,
        ),
        isTrue,
      );
    } finally {
      await db.close();
    }
  });
  test('stage 19b is covered along its full recorded route', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      File('assets/database/camino.sqlite').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final rows = await db.rawQuery(
        'SELECT t.latitude,t.longitude FROM track_points t JOIN paths p ON p.pathID=t.pathID WHERE p.stageID=25 ORDER BY t.track_point_id',
      );
      expect(rows.length, 570);
      final points = rows
          .map(
            (r) => LatLng(
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      expect(
        await OfflineCoverage.covers(
          points,
          path: File(OfflineMap.assetPath).absolute.path,
        ),
        isTrue,
      );
    } finally {
      await db.close();
    }
  });
  test(
    'asset copies once and provides actual stage corridor tiles with TMS conversion',
    () async {
      final directory = await Directory.systemTemp.createTemp('camino_maps_');
      try {
        final path = await OfflineMap.install(directory: directory.path);
        final before = await File(path).lastModified();
        expect(await OfflineMap.install(directory: directory.path), path);
        expect(await File(path).lastModified(), before);
        final provider = await MbTilesVectorTileProvider.open(path);
        try {
          expect(provider.maximumZoom, 14);
          expect(
            provider.metadata.values['name'],
            'Camino offline maps through stage 20',
          );
          expect(provider.cacheBytesToDisk, isFalse);
          final tile = await provider.load(const vt.TileKey(14, 8117, 6031));
          expect(tile, isA<vt.TileResponseData>());
          expect(
            gzip.decode((tile as vt.TileResponseData).bytes).length,
            greaterThan(10000),
          );
          expect(
            await provider.load(const vt.TileKey(14, 0, 0)),
            isA<vt.TileResponseNotFound>(),
          );
          final stage4Tile = await provider.load(
            const vt.TileKey(14, 8109, 6040),
          );
          expect(stage4Tile, isA<vt.TileResponseData>());
          expect(
            gzip.decode((stage4Tile as vt.TileResponseData).bytes).length,
            greaterThan(1000),
          );
          final stage5Tile = await provider.load(
            const vt.TileKey(14, 8099, 6040),
          );
          expect(stage5Tile, isA<vt.TileResponseData>());
          expect(
            gzip.decode((stage5Tile as vt.TileResponseData).bytes).length,
            greaterThan(1000),
          );
          final frenchTile = await provider.load(
            const vt.TileKey(14, 8135, 6010),
          );
          expect(frenchTile, isA<vt.TileResponseData>());
          expect(
            gzip.decode((frenchTile as vt.TileResponseData).bytes).length,
            greaterThan(1000),
          );
          final json =
              jsonDecode(
                    await rootBundle.loadString(
                      'assets/offline_maps/style.json',
                    ),
                  )
                  as Map;
          expect(json.containsKey('sprite'), isFalse);
          expect(json.containsKey('glyphs'), isFalse);
          expect(jsonEncode(json['sources']), isNot(contains('https://')));
        } finally {
          provider.dispose();
        }
      } finally {
        // The provider closes its SQLite reader asynchronously.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('bundled vector style renders with route overlays', (
    tester,
  ) async {
    late vt.Style style;

    await tester.runAsync(() async {
      style = await OfflineMap.load(
        path: File(
          'assets/offline_maps/stages1_22_complete.mbtiles',
        ).absolute.path,
      );
    });
    // Widget tests otherwise render labels with the square Ahem test font.
    final previewFont = Platform.environment['CAMINO_MAP_PREVIEW_FONT'];
    if (previewFont != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('CaminoMap')
          ..addFont(File(previewFont).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      });
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(43.163667, -1.234916),
                initialZoom: 17,
              ),
              children: [
                OfflineBasemap(loadStyle: () async => style),
                PolylineLayer<Object>(
                  polylines: [
                    Polyline<Object>(
                      points: const [
                        LatLng(43.163667, -1.234916),
                        LatLng(43.161, -1.238),
                      ],
                      color: Colors.green,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                const MarkerLayer(markers: []),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(vt.VectorTileLayer), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
    final previewPath = Platform.environment['CAMINO_MAP_PREVIEW'];
    if (previewPath != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(previewPath);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
