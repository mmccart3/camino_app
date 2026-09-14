import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferencesAsync _preferences;
  SettingsService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const defaultPaceKmh = 4.6;
  static const minimumPaceKmh = 1.0;
  static const maximumPaceKmh = 8.5;
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
