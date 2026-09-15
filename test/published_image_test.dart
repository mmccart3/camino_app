import 'package:camino_app/data/models.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:camino_app/data/stage_image_assets.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/published_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every bundled map and chart matches manifest and decodes offline',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/stage_images.json'))
              as Map<String, dynamic>;
      final images = manifest['images'] as Map<String, dynamic>;
      expect(images.length, 76);
      expect(StageImageAssets.paths.length, images.length);
      for (final entry in images.entries) {
        final item = entry.value as Map<String, dynamic>;
        expect(StageImageAssets.paths[entry.key], item['asset']);
        final data = await rootBundle.load(item['asset'] as String);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        expect(sha256.convert(bytes).toString(), item['sha256']);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, item['width']);
        expect(frame.image.height, item['height']);
        frame.image.dispose();
        codec.dispose();
      }
      expect(StageImageAssets.map(43), isNull);
      expect(
        StageImageAssets.elevation(1),
        'assets/elevation_charts/stage_1.png',
      );
    },
  );
  testWidgets('bundled image stays local in full-screen viewer', (
    tester,
  ) async {
    final path = StageImageAssets.map(2)!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PublishedImage(assetPath: path, title: 'Map'),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage(path),
        tester.element(find.byType(PublishedImage)),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, path);
  });

  testWidgets(
    'wide map keeps its ratio and supports full-screen zoom and reset',
    (tester) async {
      Location? opened;
      final hotspot = MapHotspot.fromRow({
        'hotspotId': 1,
        'ID': 99,
        'locationName': 'Test place',
        'TLX1920': 160,
        'TLY1920': 30,
        'BRX1920': 240,
        'BRY1920': 70,
      });
      late MemoryImage provider;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 100),
          Paint()..color = Colors.green,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 100);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        provider = MemoryImage(data!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: PublishedImage(
                    assetPath: null,
                    title: 'Map',
                    imageProvider: provider,
                    hotspots: [hotspot],
                    onLocationTap: (location) {
                      opened = location;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          provider,
          tester.element(find.byType(PublishedImage)),
        );
      });
      await tester.pumpAndSettle();
      final bounds = tester.getSize(find.byType(Image));
      expect(bounds.width, 400);
      expect(bounds.height, 100);
      final target = find.byKey(const ValueKey('map-hotspot-1'));
      expect(tester.getSize(target), const Size(80, 40));
      await tester.tap(target);
      expect(opened?.id, 99);
      expect(find.byType(InteractiveViewer), findsNothing);
      opened = null;
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      final fullTarget = find.byKey(const ValueKey('map-hotspot-1'));
      final viewerBounds = tester.getRect(find.byType(InteractiveViewer));
      expect(tester.getCenter(fullTarget), viewerBounds.center);
      await tester.tap(fullTarget);
      expect(opened?.id, 99);
      opened = null;
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(fullTarget);
      expect(opened?.id, 99);
      await tester.drag(find.byType(InteractiveViewer), const Offset(25, 10));
      await tester.pumpAndSettle();
      opened = null;
      await tester.tap(fullTarget);
      expect(opened?.id, 99);
      await tester.tap(find.byTooltip('Reset zoom'));
      await tester.pump();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PublishedImage), findsOneWidget);
    },
  );
  testWidgets('missing map shows a fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PublishedImage(assetPath: null, title: 'Map')),
      ),
    );
    expect(find.textContaining('Image unavailable'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
