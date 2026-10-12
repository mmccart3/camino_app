import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// User-owned records, separate from the replaceable guide asset.
class PersonalEntry {
  final int? id;
  final int photoCount;
  final List<String>? photoCaptions;
  final int? coverPhoto;

  /// Null preserves existing photos; an empty list removes them on save.
  final List<Uint8List>? photos;
  final String category, kind, name, locationName, date, notes, contact;
  final int sourceId, locationId;
  const PersonalEntry({
    this.id,
    this.photoCount = 0,
    this.photos,
    this.photoCaptions,
    this.coverPhoto,
    required this.category,
    required this.kind,
    required this.sourceId,
    required this.locationId,
    required this.name,
    required this.locationName,
    this.date = '',
    this.notes = '',
    this.contact = '',
  });
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'category': category,
    'kind': kind,
    'source_id': sourceId,
    'location_id': locationId,
    'name': name,
    'location_name': locationName,
    'date': date,
    'notes': notes,
    'contact': contact,
    if (photoCaptions != null) 'photo_captions': jsonEncode(photoCaptions),
    if (coverPhoto != null) 'cover_photo': coverPhoto,
  };
  factory PersonalEntry.fromMap(Map<String, Object?> r) => PersonalEntry(
    id: r['id'] as int,
    photoCount: (r['photo_count'] as int?) ?? 0,
    photoCaptions: List<String>.from(
      jsonDecode(r['photo_captions'] as String? ?? '[]') as List,
    ),
    coverPhoto: r['cover_photo'] as int? ?? 0,
    category: r['category'] as String,
    kind: r['kind'] as String,
    sourceId: r['source_id'] as int,
    locationId: r['location_id'] as int,
    name: r['name'] as String,
    locationName: r['location_name'] as String,
    date: r['date'] as String,
    notes: r['notes'] as String,
    contact: r['contact'] as String,
  );
}

class PersonalStore {
  static final instance = PersonalStore();
  final String? path;
  final DatabaseFactory? factory;
  Future<Database>? _opening;
  PersonalStore({this.path, this.factory});
  Future<Database> get database => _opening ??= _open().catchError((Object e) {
    _opening = null;
    throw e;
  });
  Future<Database> _open() async {
    if (Platform.isWindows) sqfliteFfiInit();
    final file =
        path ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'camino_personal.sqlite',
        );
    return (factory ??
            (Platform.isWindows ? databaseFactoryFfi : databaseFactory))
        .openDatabase(
          file,
          options: OpenDatabaseOptions(
            version: 3,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) await _createPhotos(db);
              if (oldVersion < 3) {
                await db.execute(
                  "ALTER TABLE entries ADD COLUMN photo_captions TEXT NOT NULL DEFAULT '[]'",
                );
                await db.execute(
                  'ALTER TABLE entries ADD COLUMN cover_photo INTEGER NOT NULL DEFAULT 0',
                );
              }
            },
            onCreate: (db, _) async {
              await db.execute(
                """CREATE TABLE entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL CHECK(category IN ('favourite', 'diary')),
          kind TEXT NOT NULL, source_id INTEGER NOT NULL, location_id INTEGER NOT NULL,
          name TEXT NOT NULL, location_name TEXT NOT NULL, date TEXT NOT NULL,
          notes TEXT NOT NULL, contact TEXT NOT NULL, photo_captions TEXT NOT NULL DEFAULT '[]', cover_photo INTEGER NOT NULL DEFAULT 0)""",
              );
              await _createPhotos(db);
              await db.execute(
                "CREATE UNIQUE INDEX unique_favourite ON entries(kind, source_id) WHERE category = 'favourite'",
              );
            },
          ),
        );
  }

  static Future<void> _createPhotos(Database db) => db.execute(
    'CREATE TABLE diary_photos (entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE, ordinal INTEGER NOT NULL, jpeg BLOB NOT NULL, PRIMARY KEY(entry_id, ordinal))',
  );

  Future<List<PersonalEntry>>
  entries() async => (await (await database).rawQuery(
    'SELECT e.*, (SELECT count(*) FROM diary_photos p WHERE p.entry_id=e.id) AS photo_count FROM entries e ORDER BY date, id',
  )).map(PersonalEntry.fromMap).toList();

  Future<List<Uint8List>> photos(int id) async => (await (await database).query(
    'diary_photos',
    columns: ['jpeg'],
    where: 'entry_id = ?',
    whereArgs: [id],
    orderBy: 'ordinal',
  )).map((r) => r['jpeg'] as Uint8List).toList();

  Future<void> save(PersonalEntry entry) async {
    if (entry.photos != null &&
        (entry.photos!.length > 12 ||
            (entry.category != 'diary' && entry.photos!.isNotEmpty))) {
      throw ArgumentError('Only diary entries can have up to 12 photos.');
    }
    await (await database).transaction((txn) async {
      var id = entry.id;
      if (id != null) {
        final changed = await txn.update(
          'entries',
          entry.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
        if (changed != 1) throw StateError('Entry no longer exists');
      } else {
        if (entry.category == 'favourite') {
          final existing = await txn.query(
            'entries',
            columns: ['id'],
            where: "category='favourite' AND kind=? AND source_id=?",
            whereArgs: [entry.kind, entry.sourceId],
          );
          if (existing.isNotEmpty) return;
        }
        id = await txn.insert('entries', entry.toMap());
      }
      if (entry.photos != null) {
        await txn.delete(
          'diary_photos',
          where: 'entry_id = ?',
          whereArgs: [id],
        );
        for (var i = 0; i < entry.photos!.length; i++) {
          await txn.insert('diary_photos', {
            'entry_id': id,
            'ordinal': i,
            'jpeg': entry.photos![i],
          });
        }
      }
    });
  }

  Future<void> delete(int id) async =>
      (await database).delete('entries', where: 'id = ?', whereArgs: [id]);
  Future<void> close() async {
    await (await database).close();
    _opening = null;
  }
}
