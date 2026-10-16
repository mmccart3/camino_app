import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/ui/widgets.dart';

void main() {
  testWidgets('failed data load retries and hides technical details', (
    tester,
  ) async {
    var attempts = 0;
    final first = Completer<String>();
    Future<String> load() async {
      attempts++;
      if (attempts == 1) return first.future;
      return 'Loaded successfully';
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataView<String>(
            future: load(),
            retry: load,
            builder: (value) => Text(value),
          ),
        ),
      ),
    );
    first.completeError(StateError('internal diagnostic token'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('internal diagnostic token'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('internal diagnostic token'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Loaded successfully'), findsOneWidget);
  });
  testWidgets(
    'retry survives parent rebuild and an explicit new future loads',
    (tester) async {
      final first = Completer<String>();
      Future<String> source = first.future;
      late StateSetter rebuild;
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: DataView<String>(
                  future: source,
                  retry: () async {
                    retries++;
                    return 'Recovered';
                  },
                  builder: (value) => Text(value),
                ),
              );
            },
          ),
        ),
      );
      first.completeError(StateError('failure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      rebuild(() {});
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
      expect(retries, 1);
      rebuild(() {
        source = Future.value('New selection');
      });
      await tester.pumpAndSettle();
      expect(find.text('New selection'), findsOneWidget);
    },
  );
  testWidgets('action retry repeats original operation', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFailure(
              context,
              StateError('secret'),
              onRetry: () async {
                calls++;
              },
            ),
            child: const Text('Fail'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fail'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
