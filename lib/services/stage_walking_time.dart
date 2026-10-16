import '../data/camino_repository.dart';
import '../data/models.dart';
import '../data/route_assembler.dart';
import 'settings_service.dart';
import 'walking_time.dart';

/// All stage summaries use the same validated route and true flat-ground speed.
Duration? routeWalkingTime(StageRoute route, double speedKmh) {
  if (!route.canGuide || route.points.length < 2) return null;
  var total = 0.0;
  for (final point in route.points.skip(1)) {
    final weight = point.weightedDistance;
    if (weight == null || !weight.isFinite || weight < 0) return null;
    total += weight;
  }
  return WalkingTime.estimate(total, speedKmh);
}

Future<Duration?> stageWalkingTime(
  Stage stage,
  CaminoRepository repository,
  SettingsService settings,
) async => routeWalkingTime(await repository.route(stage), settings.paceKmh);
