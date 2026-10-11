import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/persistent_tabs.dart';

void main() {
  testWidgets('tabs retain nested routes and back pops only the active tab', (
    tester,
  ) async {
    final key = GlobalKey<PersistentTabsState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: PersistentTabs(
          key: key,
          open: (_) => false,
          root: (context, index) => Scaffold(
            appBar: AppBar(title: Text('Root $index')),
            body: Text('Content $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    key.currentState!.keys[1].currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Detail')),
          body: const TextField(key: ValueKey('remember')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('remember')),
      'Saved position',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('My Camino'));
    await tester.pumpAndSettle();
    expect(find.text('Content 3'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Saved position'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Content 1'), findsOneWidget);
    expect(find.text('Detail'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Content 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
