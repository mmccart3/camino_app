import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/models.dart';
import 'walking_day.dart';
import 'walking_day_store.dart';

class PlannedStay {
  final int id;
  final String kind, name, status, reference, notes;
  const PlannedStay({
    required this.id,
    required this.kind,
    required this.name,
    this.status = 'Considering',
    this.reference = '',
    this.notes = '',
  });
  static const statuses = ['Considering', 'Booked', 'Confirmed'];
  factory PlannedStay.fromAccommodation(Accommodation place) => PlannedStay(
    id: place.id,
    kind: place is Albergue ? 'albergue' : 'private',
    name: place.name,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'status': status,
    'reference': reference,
    'notes': notes,
  };
  factory PlannedStay.fromJson(Map<String, dynamic> r) {
    if (!statuses.contains(r['status']) ||
        !['albergue', 'private'].contains(r['kind'])) {
      throw const FormatException('Invalid accommodation choice');
    }
    return PlannedStay(
      id: r['id'] as int,
      kind: r['kind'] as String,
      name: r['name'] as String,
      status: r['status'] as String,
      reference: r['reference'] as String,
      notes: r['notes'] as String,
    );
  }
}

class CaminoPlan {
  final int id;
  final String name;
  const CaminoPlan(this.id, this.name);
}

/// Snapshots preserve the itinerary even if a later guide removes its route.
class ItineraryDay {
  final int id, planId, order, startId, endId;
  final int? seconds;
  final String startName, endName;
  final double? metres;
  bool get hasEstimate => metres != null && seconds != null;
  final SavedWalkingDay route;
  final PlannedStay? stay;
  const ItineraryDay({
    required this.id,
    required this.planId,
    required this.order,
    required this.startId,
    required this.endId,
    required this.startName,
    required this.endName,
    required this.metres,
    required this.seconds,
    required this.route,
    this.stay,
  });
  factory ItineraryDay.fromWalkingDay(
    int planId,
    SavedWalkingDay route,
    WalkingDay day, {
    ItineraryDay? previous,
  }) => ItineraryDay(
    id: previous?.id ?? 0,
    planId: planId,
    order: previous?.order ?? 0,
    startId: day.places.first.id,
    endId: day.places.last.id,
    startName: day.places.first.name,
    endName: day.places.last.name,
    metres: day.metres,
    seconds: day.walkingTime.inSeconds,
    route: route,
    stay: previous?.endId == day.places.last.id ? previous?.stay : null,
  );
  Map<String, Object?> get row => {
    'plan_id': planId,
    'ordinal': order,
    'start_id': startId,
    'end_id': endId,
    'start_name': startName,
    'end_name': endName,
    'metres': metres,
    'seconds': seconds,
    'route': jsonEncode(route.toJson()),
    'stay': stay == null ? null : jsonEncode(stay!.toJson()),
  };
  factory ItineraryDay.fromRow(Map<String, Object?> r) => ItineraryDay(
    id: r['id'] as int,
    planId: r['plan_id'] as int,
    order: r['ordinal'] as int,
    startId: r['start_id'] as int,
    endId: r['end_id'] as int,
    startName: r['start_name'] as String,
    endName: r['end_name'] as String,
    metres: (r['metres'] as num?)?.toDouble(),
    seconds: r['seconds'] as int?,
    route: SavedWalkingDay.fromJson(
      jsonDecode(r['route'] as String) as Map<String, dynamic>,
      allowEmptyPaths: true,
    ),
    stay: r['stay'] == null
        ? null
        : PlannedStay.fromJson(
            jsonDecode(r['stay'] as String) as Map<String, dynamic>,
          ),
  );
  Duration get totalDuration => Duration(
    seconds: seconds ?? 0,
    minutes: route.breaks.values.fold(0, (a, b) => a + b),
  );
  String? warningAfter(ItineraryDay previous) {
    if (previous.endId != startId) {
      return 'This day does not start where the previous day ends.';
    }
    final before = DateTime.tryParse(previous.route.date ?? '');
    final after = DateTime.tryParse(route.date ?? '');
    if (before != null && after != null && !after.isAfter(before)) {
      return 'Check dates: this day is not after the previous day.';
    }
    return null;
  }
}

/// Never copied from or replaced with the bundled guide database.
class CaminoPlanStore {
  static final instance = CaminoPlanStore();
  final String? path;
  final DatabaseFactory? factory;
  Future<Database>? _opening;
  CaminoPlanStore({this.path, this.factory});
  Future<Database> get database => _opening ??= _open().catchError((Object e) {
    _opening = null;
    throw e;
  });
  Future<Database> _open() async {
    if (Platform.isWindows) sqfliteFfiInit();
    final f =
        factory ?? (Platform.isWindows ? databaseFactoryFfi : databaseFactory);
    final file =
        path ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'camino_user_plans.sqlite',
        );
    if (file != inMemoryDatabasePath) {
      await Directory(p.dirname(file)).create(recursive: true);
    }
    return f.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE plans (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
          );
          await db.execute('''CREATE TABLE days (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
          ordinal INTEGER NOT NULL, start_id INTEGER NOT NULL, end_id INTEGER NOT NULL,
          start_name TEXT NOT NULL, end_name TEXT NOT NULL, metres REAL,
          seconds INTEGER, route TEXT NOT NULL, stay TEXT)''');
          await db.execute('CREATE INDEX days_plan ON days(plan_id, ordinal)');
        },
      ),
    );
  }

  Future<List<CaminoPlan>> plans() async => (await (await database).query(
    'plans',
    orderBy: 'id',
  )).map((r) => CaminoPlan(r['id'] as int, r['name'] as String)).toList();
  Future<int> create(String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a plan name');
    return (await database).insert('plans', {'name': name.trim()});
  }

  Future<void> rename(int id, String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a plan name');
    await (await database).update(
      'plans',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ItineraryDay>> days(int planId) async =>
      (await (await database).query(
        'days',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'ordinal, id',
      )).map(ItineraryDay.fromRow).toList();
  Future<int> saveDay(ItineraryDay day) async => (await database).transaction((
    tx,
  ) async {
    final row = day.row;
    if (day.id != 0) {
      // Stay is managed separately, so editing a route cannot overwrite a newer booking.
      final old = await tx.query(
        'days',
        where: 'id = ? AND plan_id = ?',
        whereArgs: [day.id, day.planId],
      );
      if (old.isEmpty) throw StateError('This day has been deleted');
      row['stay'] = old.single['end_id'] == day.endId
          ? old.single['stay']
          : null;
      await tx.update('days', row, where: 'id = ?', whereArgs: [day.id]);
      return day.id;
    }
    final last = await tx.rawQuery(
      'SELECT MAX(ordinal) AS n FROM days WHERE plan_id = ?',
      [day.planId],
    );
    row['ordinal'] = ((last.single['n'] as int?) ?? -1) + 1;
    return tx.insert('days', row);
  });
  Future<void> setStay(
    int dayId,
    PlannedStay? stay, {
    required int locationId,
  }) async {
    final n = await (await database).update(
      'days',
      {'stay': stay == null ? null : jsonEncode(stay.toJson())},
      where: 'id = ? AND end_id = ?',
      whereArgs: [dayId, locationId],
    );
    if (n != 1) throw StateError('The destination changed. Reopen your plan.');
  }

  Future<void> deleteDay(int id) async {
    await (await database).delete('days', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePlan(int id) async {
    await (await database).delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
