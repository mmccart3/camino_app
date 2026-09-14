import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camino_app/data/models.dart';
import 'package:camino_app/data/route_assembler.dart';
import 'package:camino_app/services/navigation_session.dart';
import 'package:camino_app/services/route_notifications.dart';

class Notices extends RouteNotifications {
  bool deny = false;
  final List<String> messages = [];
  @override
  Future<void> prepare() async {
    if (deny) throw StateError('Denied');
  }

  @override
  Future<void> show(String title, String message) async {
    messages.add(title);
  }

  @override
  Future<void> clear() async {}
}

StageRoute route() => StageRoute(
  stage: Stage.fromRow({
    'ID': 1,
    'stageName': 'Test walk',
    'stageStartLocationID': 1,
    'stageFinishLocationID': 2,
  }),
  paths: [],
  locations: [],
  segments: [],
  issues: [],
  locationsOrdered: true,
  points: [
    for (var i = 0; i < 2; i++)
      TrackPoint.fromRow({
        'track_point_id': i + 1,
        'pathID': 1,
        'latitude': 42.0,
        'longitude': -1.0 + i * .01,
      }),
  ],
);
void main() {
  test('cancel during permission prompt never opens a GPS stream', () async {
    final permission = Completer<void>();
    var opened = false;
    final session = NavigationSession(
      notifications: Notices(),
      mobileSupported: true,
      permissionCheck: () => permission.future,
      positionStream: (_) {
        opened = true;
        return const Stream.empty();
      },
      serviceStream: () => const Stream.empty(),
    );
    final pending = session.start(route(), 50);
    expect(session.starting, true);
    await session.stop();
    permission.complete();
    await pending;
    expect(opened, false);
    expect(session.active, false);
    session.dispose();
  });
  test('denied notifications do not start tracking', () async {
    var opened = false;
    final notices = Notices()..deny = true;
    final session = NavigationSession(
      notifications: notices,
      mobileSupported: true,
      permissionCheck: () async {},
      positionStream: (_) {
        opened = true;
        return const Stream.empty();
      },
      serviceStream: () => const Stream.empty(),
    );
    await expectLater(session.start(route(), 50), throwsStateError);
    expect(opened, false);
    expect(session.active, false);
    session.dispose();
  });
  test(
    'one session only; stop cancels GPS and service subscriptions',
    () async {
      final positions = StreamController<Position>();
      final services = StreamController<ServiceStatus>();
      final session = NavigationSession(
        notifications: Notices(),
        mobileSupported: true,
        permissionCheck: () async {},
        positionStream: (_) => positions.stream,
        serviceStream: () => services.stream,
      );
      await session.start(route(), 50);
      expect(session.active, true);
      expect(positions.hasListener, true);
      await expectLater(session.start(route(), 50), throwsStateError);
      await session.stop();
      expect(session.active, false);
      expect(positions.hasListener, false);
      expect(services.hasListener, false);
      await positions.close();
      await services.close();
      session.dispose();
    },
  );
  test(
    'turning location off stops tracking and posts a failure notice',
    () async {
      final positions = StreamController<Position>();
      final services = StreamController<ServiceStatus>();
      final notices = Notices();
      final session = NavigationSession(
        notifications: notices,
        mobileSupported: true,
        permissionCheck: () async {},
        positionStream: (_) => positions.stream,
        serviceStream: () => services.stream,
      );
      await session.start(route(), 50);
      services.add(ServiceStatus.disabled);
      await Future<void>.delayed(Duration.zero);
      expect(session.active, false);
      expect(positions.hasListener, false);
      expect(notices.messages, contains('Camino walking alerts stopped'));
      await positions.close();
      await services.close();
      session.dispose();
    },
  );
}
