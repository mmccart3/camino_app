import 'package:shared_preferences/shared_preferences.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final values = <String, double>{};
  @override
  Future<double?> getDouble(String key) async => values[key];
  @override
  Future<void> setDouble(String key, double value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
