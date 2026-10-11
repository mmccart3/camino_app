import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/services/personal_store.dart';

void main() {
  sqfliteFfiInit();
  test(
    'favourites are unique by kind; diary entries persist independently',
    () async {
      final dir = await Directory.systemTemp.createTemp('camino-personal-test');
      final path = '${dir.path}/personal.sqlite';
      var store = PersonalStore(path: path, factory: databaseFactoryFfi);
      PersonalEntry entry(
        String category,
        String kind, {
        int? id,
        String notes = 'A note',
      }) => PersonalEntry(
        id: id,
        category: category,
        kind: kind,
        sourceId: 7,
        locationId: 1,
        name: 'Test stay',
        locationName: 'Saint Jean',
        date: category == 'diary' ? '2026-10-11' : '',
        notes: notes,
      );
      try {
        await store.save(entry('favourite', 'albergue'));
        await store.save(entry('favourite', 'albergue'));
        await store.save(entry('favourite', 'private'));
        await store.save(entry('diary', 'albergue'));
        await store.save(entry('diary', 'albergue'));
        var entries = await store.entries();
        expect(entries.length, 4);
        final favourite = entries.firstWhere(
          (e) => e.category == 'favourite' && e.kind == 'albergue',
        );
        await store.save(
          entry('favourite', 'albergue', id: favourite.id, notes: 'Changed'),
        );
        await store.close();
        store = PersonalStore(path: path, factory: databaseFactoryFfi);
        entries = await store.entries();
        expect(
          entries.singleWhere((e) => e.id == favourite.id).notes,
          'Changed',
        );
        await store.delete(favourite.id!);
        expect(
          (await store.entries()).where((e) => e.category == 'diary').length,
          2,
        );
        expect((await store.entries()).length, 3);
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'version 1 upgrade preserves notes; photos save, survive edits and cascade on delete',
    () async {
      final dir = await Directory.systemTemp.createTemp('camino-photo-test');
      final path = '${dir.path}/personal.sqlite';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              "CREATE TABLE entries (id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL, kind TEXT NOT NULL, source_id INTEGER NOT NULL, location_id INTEGER NOT NULL, name TEXT NOT NULL, location_name TEXT NOT NULL, date TEXT NOT NULL, notes TEXT NOT NULL, contact TEXT NOT NULL)",
            );
            await db.insert(
              'entries',
              const PersonalEntry(
                category: 'diary',
                kind: 'location',
                sourceId: 1,
                locationId: 1,
                name: 'Old entry',
                locationName: 'León',
                date: '2026-10-10',
                notes: 'Keep me',
              ).toMap(),
            );
          },
        ),
      );
      await old.close();
      final store = PersonalStore(path: path, factory: databaseFactoryFfi);
      try {
        var original = (await store.entries()).single;
        expect(original.notes, 'Keep me');
        expect(original.photoCount, 0);
        PersonalEntry edited({List<Uint8List>? photos}) => PersonalEntry(
          id: original.id,
          category: 'diary',
          kind: 'location',
          sourceId: 1,
          locationId: 1,
          name: 'Old entry',
          locationName: 'León',
          date: '2026-10-10',
          notes: 'Edited',
          photos: photos,
        );
        final data = Uint8List.fromList([1, 2, 3]);
        await store.save(edited(photos: [data]));
        await store.close();
        expect((await store.entries()).single.photoCount, 1);
        expect((await store.photos(original.id!)).single, data);
        await store.save(edited());
        expect((await store.photos(original.id!)).length, 1);
        await store.save(edited(photos: []));
        expect((await store.photos(original.id!)), isEmpty);
        await store.save(edited(photos: [data]));
        await store.delete(original.id!);
        expect(await (await store.database).query('diary_photos'), isEmpty);
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
