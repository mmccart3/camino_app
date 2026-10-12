import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'personal_store.dart';

/// Portable, versioned diary-only backup. No guide database or itinerary is replaced.
class DiaryBackup {
  static const maxBytes = 128 * 1024 * 1024;
  static String fingerprint(Map<String, Object?> entry) =>
      sha256.convert(utf8.encode(jsonEncode(entry))).toString();

  static Map<String, Object?> record(PersonalEntry e, List<Uint8List> photos) =>
      {
        'kind': e.kind,
        'source_id': e.sourceId,
        'location_id': e.locationId,
        'name': e.name,
        'location_name': e.locationName,
        'date': e.date,
        'notes': e.notes,
        'contact': e.contact,
        'photos': photos.map(base64Encode).toList(),
        'captions': List.generate(
          photos.length,
          (i) => i < (e.photoCaptions?.length ?? 0) ? e.photoCaptions![i] : '',
        ),
        'cover': photos.isEmpty
            ? 0
            : (e.coverPhoto ?? 0).clamp(0, photos.length - 1),
      };

  static Future<Uint8List> export(PersonalStore store) async {
    final db = await store.database;
    final records = await db.transaction((tx) async {
      final rows = await tx.query(
        'entries',
        where: "category = 'diary'",
        orderBy: 'date, id',
      );
      if (rows.length > 10000) {
        throw const FormatException('Too many diary entries for one backup.');
      }
      final result = <Map<String, Object?>>[];
      var size = 0;
      for (final row in rows) {
        final photos = await tx.query(
          'diary_photos',
          where: 'entry_id = ?',
          whereArgs: [row['id']],
          orderBy: 'ordinal',
        );
        final r = record(
          PersonalEntry.fromMap(row),
          photos.map((p) => p['jpeg'] as Uint8List).toList(),
        );
        size += utf8.encode(jsonEncode(r)).length;
        if (size > maxBytes - 1024) {
          throw const FormatException('Diary backup exceeds the 128 MB limit.');
        }
        result.add(r);
      }
      return result;
    });
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'saint-jean-to-santiago-diary',
          'version': 2,
          'entries': records,
        }),
      ),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('Diary backup exceeds the 128 MB limit.');
    }
    return bytes;
  }

  static List<PersonalEntry> decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds 128 MB.');
    }
    final root = jsonDecode(utf8.decode(bytes));
    if (root is! Map ||
        root['format'] != 'saint-jean-to-santiago-diary' ||
        ![1, 2].contains(root['version']) ||
        root['entries'] is! List) {
      throw const FormatException('Not a supported Camino diary backup.');
    }
    final rows = root['entries'] as List;
    if (rows.length > 10000) {
      throw const FormatException('Too many diary entries.');
    }
    return rows.map((r) {
      if (r is! Map) throw const FormatException('Invalid diary entry.');
      for (final key in [
        'kind',
        'name',
        'location_name',
        'date',
        'notes',
        'contact',
      ]) {
        if (r[key] is! String || (r[key] as String).length > 20000) {
          throw const FormatException('Invalid diary text.');
        }
      }
      if (!['location', 'albergue', 'private', 'journal'].contains(r['kind']) ||
          r['source_id'] is! int ||
          r['location_id'] is! int ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(r['date'] as String) ||
          DateTime.tryParse(
                r['date'] as String,
              )?.toIso8601String().split('T').first !=
              r['date'] ||
          r['photos'] is! List ||
          (r['photos'] as List).length > 12) {
        throw const FormatException('Invalid diary details.');
      }
      final photos = (r['photos'] as List).map((value) {
        if (value is! String) throw const FormatException('Invalid photo.');
        final b = base64Decode(value);
        if (b.length < 4 ||
            b.length > 8 * 1024 * 1024 ||
            b[0] != 255 ||
            b[1] != 216 ||
            b[b.length - 2] != 255 ||
            b.last != 217) {
          throw const FormatException('Invalid JPEG photo.');
        }
        return b;
      }).toList();
      final captions = root['version'] == 1
          ? List.filled(photos.length, '')
          : r['captions'];
      final cover = root['version'] == 1 ? 0 : r['cover'];
      if (captions is! List ||
          captions.length != photos.length ||
          captions.any((c) => c is! String || c.length > 500) ||
          cover is! int ||
          cover < 0 ||
          cover >= (photos.isEmpty ? 1 : photos.length)) {
        throw const FormatException('Invalid photo captions or cover.');
      }
      return PersonalEntry(
        category: 'diary',
        kind: r['kind'] as String,
        sourceId: r['source_id'] as int,
        locationId: r['location_id'] as int,
        name: r['name'] as String,
        locationName: r['location_name'] as String,
        date: r['date'] as String,
        notes: r['notes'] as String,
        contact: r['contact'] as String,
        photos: photos,
        photoCaptions: List<String>.from(captions),
        coverPhoto: cover,
      );
    }).toList();
  }

  /// One transaction: failures roll back; identical entries are skipped.
  static Future<int> restore(
    PersonalStore store,
    List<PersonalEntry> incoming,
  ) async {
    return (await store.database).transaction((tx) async {
      final seen = <String>{};
      for (final row in await tx.query(
        'entries',
        where: "category = 'diary'",
      )) {
        final photos = await tx.query(
          'diary_photos',
          where: 'entry_id = ?',
          whereArgs: [row['id']],
          orderBy: 'ordinal',
        );
        seen.add(
          fingerprint(
            record(
              PersonalEntry.fromMap(row),
              photos.map((p) => p['jpeg'] as Uint8List).toList(),
            ),
          ),
        );
      }
      var added = 0;
      for (final entry in incoming) {
        final photos = entry.photos ?? [];
        if (!seen.add(fingerprint(record(entry, photos)))) continue;
        final id = await tx.insert('entries', entry.toMap()..remove('id'));
        for (var i = 0; i < photos.length; i++) {
          await tx.insert('diary_photos', {
            'entry_id': id,
            'ordinal': i,
            'jpeg': photos[i],
          });
        }
        added++;
      }
      return added;
    });
  }
}
