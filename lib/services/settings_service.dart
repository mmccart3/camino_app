import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferencesAsync _preferences;
  SettingsService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const defaultPaceKmh = 4.6;
  static const minimumPaceKmh = 1.0;
  static const maximumPaceKmh = 8.5;
  double _pace = defaultPaceKmh;
  double get paceKmh => _pace;
  Future<void> load() async {
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
