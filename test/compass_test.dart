import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:camino_app/services/compass_heading.dart';
import 'package:camino_app/ui/compass_layer.dart';

void main() {
  test(
    'heading smoothing takes short route across north in both directions',
    () {
      final heading = CompassHeading();
      expect(heading.update(359), 359);
      expect(heading.update(1), closeTo(359.6, 0.001));
      heading.reset();
      expect(heading.update(1), 1);
      expect(heading.update(359), closeTo(0.4, 0.001));
      expect(CompassHeading.direction(359), 'N');
      expect(CompassHeading.direction(90), 'E');
      expect(() => heading.update(double.nan), throwsArgumentError);
    },
  );

  testWidgets('compass rotation toggles and pauses for a manual drag', (
    tester,
  ) async {
    final events = StreamController<dynamic>.broadcast();
    final map = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: map,
            options: const MapOptions(initialCenter: LatLng(42, -2)),
            children: [CompassLayer(events: events.stream)],
          ),
        ),
      ),
    );
    events.add({'heading': 90.0, 'reliable': true});
    await tester.pump();
    expect(map.camera.rotation, 0);
    await tester.tap(find.text('Compass up'));
    await tester.pumpAndSettle();
    expect((map.camera.rotation + 360) % 360, closeTo(270, 0.01));
    await tester.tap(find.text('North up'));
    await tester.pumpAndSettle();
    expect(map.camera.rotation % 360, closeTo(0, 0.01));
    await tester.tap(find.text('Compass up'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(find.text('Resume compass'), findsOneWidget);
    final paused = map.camera.rotation;
    events.add({'heading': 180.0, 'reliable': true});
    await tester.pump(const Duration(milliseconds: 300));
    expect(map.camera.rotation, paused);
    await tester.pumpWidget(const SizedBox());
    await events.close();
    map.dispose();
  });

  testWidgets('stationary heading, bad readings and lifecycle cancellation', (
    tester,
  ) async {
    var listens = 0, cancels = 0;
    final stream = StreamController<dynamic>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(42, -2),
              initialRotation: 90,
            ),
            children: [
              CompassLayer(
                position: const LatLng(42, -2),
                events: stream.stream,
              ),
            ],
          ),
        ),
      ),
    );
    expect(listens, 1);
    stream.add({'heading': 90.0, 'reliable': true});
    await tester.pump();
    expect(find.textContaining('Phone facing E 90'), findsOneWidget);
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .single;
    expect(marker.rotate, false); // Map supplies its rotation once.
    stream.add({'heading': 100.0, 'reliable': false});
    await tester.pump();
    expect(find.byIcon(Icons.navigation), findsNothing);
    expect(find.textContaining('needs calibration'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(cancels, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(listens, 2);
    stream.add(null);
    await tester.pump();
    expect(find.textContaining('reading unavailable'), findsOneWidget);
    stream.add({'heading': 0.0, 'reliable': true});
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(find.byIcon(Icons.navigation), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(cancels, 2);
    await stream.close();
  });
}
