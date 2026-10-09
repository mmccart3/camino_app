import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferencesAsync _preferences;
  SettingsService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const defaultPaceKmh = 4.2;
  static const minimumPaceKmh = 1.0;
  static const maximumPaceKmh = 8.5;
  bool autoPosition = false;
  bool followPosition = false;
  int positionIntervalSeconds = 120;
  static const positionIntervals = [30, 60, 120, 300, 600];
  Future<void> setAutoPosition(bool value) async {
    await _preferences.setBool('auto_position', value);
    autoPosition = value;
    notifyListeners();
  }

  Future<void> setFollowPosition(bool value) async {
    await _preferences.setBool('follow_position', value);
    followPosition = value;
    notifyListeners();
  }

  Future<void> setPositionInterval(int value) async {
    if (!positionIntervals.contains(value)) {
      throw ArgumentError('Invalid update interval');
    }
    await _preferences.setInt('position_interval_seconds', value);
    positionIntervalSeconds = value;
    notifyListeners();
  }

  double offRouteMetres = 50;
  Future<void> setOffRouteMetres(double value) async {
    if (!value.isFinite || value < 20 || value > 500) {
      throw ArgumentError('Distance must be 20–500 metres.');
    }
    await _preferences.setDouble('off_route_metres', value);
    offRouteMetres = value;
    notifyListeners();
  }

  double _pace = defaultPaceKmh;
  double get paceKmh => _pace;
  Future<void> load() async {
    autoPosition = await _preferences.getBool('auto_position') ?? false;
    followPosition = await _preferences.getBool('follow_position') ?? false;
    final interval = await _preferences.getInt('position_interval_seconds');
    if (positionIntervals.contains(interval)) {
      positionIntervalSeconds = interval!;
    }
    final threshold = await _preferences.getDouble('off_route_metres');
    if (threshold != null &&
        threshold.isFinite &&
        threshold >= 20 &&
        threshold <= 500) {
      offRouteMetres = threshold;
    }
    final saved = await _preferences.getDouble('walking_pace_kmh');
    if (saved != null &&
        saved.isFinite &&
        saved >= minimumPaceKmh &&
        saved <= maximumPaceKmh) {
      _pace = saved;
    }
    notifyListeners();
  }

  Future<void> setPace(double value) async {
    if (!value.isFinite || value < minimumPaceKmh || value > maximumPaceKmh) {
      throw ArgumentError('Pace must be 1.0–8.5 km/h.');
    }
    await _preferences.setDouble('walking_pace_kmh', value);
    _pace = value;
    notifyListeners();
  }
}
