import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/navigation_summary.dart';

void main() {
  test('walking duration rounds up and displays hours', () {
    expect(
      navigationTime(const Duration(minutes: 75, seconds: 1)),
      '1 hr 16 min',
    );
    expect(navigationTime(null), 'Unavailable');
  });
  testWidgets('guidance wraps on small screens with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: NavigationSummary(
                title: 'Next: Saint Jean Pied de Port',
                distance: '12.45 km',
                time: '3 hr 25 min',
                remaining: '24.90 km / 7 hr 15 min to stage end',
                warning: '120 m from the route',
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3 hr 25 min'), findsOneWidget);
  });
}
