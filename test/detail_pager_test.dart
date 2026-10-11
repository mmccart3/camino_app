import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/detail_pager.dart';

void main() {
  testWidgets('swipes and labelled controls preserve each detail page state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: DetailPager<String>(
            items: const ['First', 'Second', 'Third'],
            initialIndex: 1,
            label: (s) => s,
            builder: (s) => Scaffold(
              body: ListView(
                children: [
                  Text(s),
                  TextField(key: ValueKey(s)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('Second')), 'Remember me');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
    await tester.tap(find.text('‹ Previous\nSecond'));
    await tester.pumpAndSettle();
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.text('‹ Previous\nFirst'));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
  });
  testWidgets('an interactive child keeps horizontal map gestures', (
    tester,
  ) async {
    var drags = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: DetailPager<int>(
            items: const [1, 2],
            initialIndex: 0,
            label: (n) => '$n',
            builder: (n) => GestureDetector(
              onHorizontalDragUpdate: (_) => drags++,
              child: ColoredBox(
                color: Colors.blue,
                child: Center(child: Text('Map $n')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.text('Map 1'), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(drags, greaterThan(0));
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('Next ›\n2'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });
}
