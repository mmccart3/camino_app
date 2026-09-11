import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/published_image.dart';

void main() {
  testWidgets(
    'wide map keeps its ratio and supports full-screen zoom and reset',
    (tester) async {
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
                    url: null,
                    title: 'Map',
                    imageProvider: provider,
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
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
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
        home: Scaffold(body: PublishedImage(url: null, title: 'Map')),
      ),
    );
    expect(find.textContaining('Image unavailable'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
