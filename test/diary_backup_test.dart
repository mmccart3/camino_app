import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:camino_app/services/personal_store.dart';
import 'package:camino_app/services/diary_backup.dart';

void main() {
  sqfliteFfiInit();
  test(
    'backup round trip preserves text and photos and repeated restore is harmless',
    () async {
      final dir = await Directory.systemTemp.createTemp('diary-backup-test');
      final source = PersonalStore(
        path: '${dir.path}/source.sqlite',
        factory: databaseFactoryFfi,
      );
      final target = PersonalStore(
        path: '${dir.path}/target.sqlite',
        factory: databaseFactoryFfi,
      );
      try {
        final photo = Uint8List.fromList(
          img.encodeJpg(img.Image(width: 2, height: 2)),
        );
        await source.save(
          PersonalEntry(
            category: 'diary',
            kind: 'location',
            sourceId: 7,
            locationId: 7,
            name: 'León',
            locationName: 'León',
            date: '2026-10-12',
            notes: 'A lovely day — café and sunshine.',
            photos: [photo],
          ),
        );
        await source.save(
          const PersonalEntry(
            category: 'favourite',
            kind: 'location',
            sourceId: 8,
            locationId: 8,
            name: 'Favourite',
            locationName: 'Town',
          ),
        );
        final entries = DiaryBackup.decode(await DiaryBackup.export(source));
        expect(entries.length, 1);
        expect(await DiaryBackup.restore(target, entries), 1);
        expect(await DiaryBackup.restore(target, entries), 0);
        final restored = (await target.entries()).single;
        expect(restored.notes, entries.single.notes);
        expect(await target.photos(restored.id!), [photo]);
        await target.save(
          PersonalEntry(
            id: restored.id,
            category: 'diary',
            kind: restored.kind,
            sourceId: 7,
            locationId: 7,
            name: restored.name,
            locationName: restored.locationName,
            date: restored.date,
            notes: 'Edited locally',
          ),
        );
        expect(await DiaryBackup.restore(target, entries), 1);
        expect((await target.entries()).length, 2);
        expect(
          (await target.entries()).any((e) => e.notes == 'Edited locally'),
          isTrue,
        );
      } finally {
        await source.close();
        await target.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('malformed and future versions are rejected before restore', () {
    expect(
      () => DiaryBackup.decode(Uint8List.fromList(utf8.encode('{}'))),
      throwsFormatException,
    );
    expect(
      () => DiaryBackup.decode(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'format': 'saint-jean-to-santiago-diary',
              'version': 2,
              'entries': [],
            }),
          ),
        ),
      ),
      throwsFormatException,
    );
    final row = DiaryBackup.record(
      const PersonalEntry(
        category: 'diary',
        kind: 'journal',
        sourceId: 0,
        locationId: 0,
        name: 'Day',
        locationName: '',
        date: '2026-02-31',
      ),
      [],
    );
    expect(
      () => DiaryBackup.decode(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'format': 'saint-jean-to-santiago-diary',
              'version': 1,
              'entries': [row],
            }),
          ),
        ),
      ),
      throwsFormatException,
    );
  });
}
