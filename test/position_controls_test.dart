import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camino_app/services/settings_service.dart';
import 'package:camino_app/ui/position_controls.dart';
import 'test_support.dart';

void main() {
  test('refresh settings persist with safe defaults and validation', () async {
    final memory = MemoryPreferences();
    final settings = SettingsService(preferences: memory);
    expect(settings.autoPosition, false);
    expect(settings.positionIntervalSeconds, 120);
    await settings.setAutoPosition(true);
    await settings.setFollowPosition(true);
    await settings.setPositionInterval(300);
    final restored = SettingsService(preferences: memory);
    await restored.load();
    expect(restored.autoPosition, true);
    expect(restored.followPosition, true);
    expect(restored.positionIntervalSeconds, 300);
    await expectLater(settings.setPositionInterval(0), throwsArgumentError);
    memory.intValues['position_interval_seconds'] = -1;
    final fallback = SettingsService(preferences: memory);
    await fallback.load();
    expect(fallback.positionIntervalSeconds, 120);
    settings.dispose();
    restored.dispose();
    fallback.dispose();
  });
  testWidgets('off by default, refresh interval, no overlap, lifecycle pause', (
    tester,
  ) async {
    final settings = SettingsService(preferences: MemoryPreferences());
    var calls = 0;
    final pending = Completer<Position>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PositionControls(
              settings: settings,
              onPosition: (_) {},
              locate: () {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 0);
    await settings.setAutoPosition(true);
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(minutes: 4));
    expect(calls, 1); // An outstanding request is never duplicated.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 4));
    expect(calls, 1);
    await settings.setAutoPosition(false);
    pending.completeError(StateError('test GPS unavailable'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
