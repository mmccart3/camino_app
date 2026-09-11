import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferencesAsync _preferences;
  SettingsService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  double _pace = 4.5;
  double get paceKmh => _pace;
  Future<void> load() async {
    final saved = await _preferences.getDouble('walking_pace_kmh');
    if (saved != null && saved.isFinite && saved >= 1 && saved <= 8) {
      _pace = saved;
    }
    notifyListeners();
  }

  Future<void> setPace(double value) async {
    if (!value.isFinite || value < 1 || value > 8) {
      throw ArgumentError('Pace must be 1–8 km/h.');
    }
    await _preferences.setDouble('walking_pace_kmh', value);
    _pace = value;
    notifyListeners();
  }
}
