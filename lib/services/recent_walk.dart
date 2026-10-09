import 'package:shared_preferences/shared_preferences.dart';

/// Remembers a screen, never starts GPS or a walking-alert session.
class RecentWalk {
  static final _preferences = SharedPreferencesAsync();
  static Future<void> save(int stageId, {required bool map}) async {
    // A single value keeps the stage and destination screen consistent.
    await _preferences.setString(
      'recent_walk',
      '$stageId:${map ? "map" : "stage"}',
    );
  }

  static Future<(int, bool)?> load() async {
    final value = await _preferences.getString('recent_walk');
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final id = int.tryParse(parts[0]);
    if (id == null || id <= 0 || !['map', 'stage'].contains(parts[1])) {
      return null;
    }
    return (id, parts[1] == 'map');
  }
}
