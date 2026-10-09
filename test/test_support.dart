import 'package:shared_preferences/shared_preferences.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final values = <String, double>{};
  @override
  Future<double?> getDouble(String key) async => values[key];
  @override
  Future<void> setDouble(String key, double value) async {
    values[key] = value;
  }

  final boolValues = <String, bool>{};
  final intValues = <String, int>{};
  @override
  Future<bool?> getBool(String key) async => boolValues[key];
  @override
  Future<void> setBool(String key, bool value) async {
    boolValues[key] = value;
  }

  @override
  Future<int?> getInt(String key) async => intValues[key];
  @override
  Future<void> setInt(String key, int value) async {
    intValues[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
