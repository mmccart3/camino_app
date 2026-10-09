import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedWalkingDay {
  final String id;
  final List<int> pathIds;
  final double pace;
  final String? date;
  final int departureMinutes;
  final Map<int, int> breaks;
  const SavedWalkingDay(
    this.id,
    this.pathIds,
    this.pace,
    this.date, {
    this.departureMinutes = 480,
    this.breaks = const {},
  });
  Map<String, Object?> toJson() => {
    'id': id,
    'paths': pathIds,
    'pace': pace,
    'date': date,
    'departureMinutes': departureMinutes,
    'breaks': {
      for (final entry in breaks.entries) entry.key.toString(): entry.value,
    },
  };
  factory SavedWalkingDay.fromJson(
    Map<String, dynamic> row, {
    bool allowEmptyPaths = false,
  }) {
    final paths = (row['paths'] as List).cast<int>();
    final pace = (row['pace'] as num).toDouble();
    final departure = row['departureMinutes'] ?? 480;
    final breaks = <int, int>{};
    final rawBreaks = row['breaks'] ?? <String, dynamic>{};
    if (rawBreaks is! Map) throw const FormatException('Invalid saved breaks.');
    for (final entry in rawBreaks.entries) {
      final id = int.tryParse(entry.key.toString());
      final minutes = entry.value;
      if (id == null ||
          id <= 0 ||
          minutes is! int ||
          minutes < 0 ||
          minutes > 1440) {
        throw const FormatException('Invalid saved break duration.');
      }
      if (minutes > 0) breaks[id] = minutes;
    }

    if (departure is! int || departure < 0 || departure >= 1440) {
      throw const FormatException('Invalid departure time.');
    }
    if ((!allowEmptyPaths && paths.isEmpty) ||
        !pace.isFinite ||
        pace < 1 ||
        pace > 8.5) {
      throw const FormatException('Invalid saved walking day.');
    }
    return SavedWalkingDay(
      row['id'] as String,
      paths,
      pace,
      row['date'] as String?,
      departureMinutes: departure,
      breaks: Map.unmodifiable(breaks),
    );
  }
}

/// Separate from the replaceable guide database. No network or GPS data.
class WalkingDayStore {
  static const key = 'walking_days_v1';
  Future<List<SavedWalkingDay>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return [];
    return (jsonDecode(text) as List)
        .map(
          (r) => SavedWalkingDay.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<void> save(List<SavedWalkingDay> plans) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key,
      jsonEncode(plans.map((p) => p.toJson()).toList()),
    )) {
      throw StateError('Could not save your walking days.');
    }
  }

  Future<void> clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(key)) {
      throw StateError('Could not delete your walking days.');
    }
  }
}
