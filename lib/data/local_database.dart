import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'schema.dart';

class LocalDatabase {
  final DatabaseFactory factory;
  final Future<Uint8List> Function() loadAsset;
  final String? directory;
  Future<Database>? _opening;
  LocalDatabase({
    DatabaseFactory? factory,
    Future<Uint8List> Function()? loadAsset,
    this.directory,
  }) : factory = factory ?? _platformFactory(),
       loadAsset =
           loadAsset ??
           (() async {
             final data = await rootBundle.load(
               'assets/database/camino.sqlite',
             );
             return data.buffer.asUint8List(
               data.offsetInBytes,
               data.lengthInBytes,
             );
           });

  static DatabaseFactory _platformFactory() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<Database> get database =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });

  Future<Database> _open() async {
    // Content-addressed copies follow the asset in this app build, including
    // upgrades from earlier fixed filenames. Preferences are stored separately.
    final asset = await loadAsset();
    final fingerprint = sha256.convert(asset).toString();
    final folder =
        directory ??
        (Platform.isWindows
            ? p.join((await getApplicationSupportDirectory()).path, 'databases')
            : await factory.getDatabasesPath());
    await Directory(folder).create(recursive: true);
    final destination = File(p.join(folder, 'camino-$fingerprint.sqlite'));
    if (!await destination.exists()) {
      final temporary = File('${destination.path}.tmp');
      try {
        await temporary.writeAsBytes(asset, flush: true);
        final candidate = await factory.openDatabase(
          temporary.path,
          options: OpenDatabaseOptions(readOnly: true),
        );
        try {
          await validate(candidate);
        } finally {
          await candidate.close();
        }
        await temporary.rename(destination.path);
      } finally {
        if (await temporary.exists()) {
          await temporary.delete();
        }
      }
    }
    final db = await factory.openDatabase(
      destination.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      await validate(db);
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<void> validate(Database db) async {
    final check = await db.rawQuery('PRAGMA quick_check');
    if (check.single.values.single != 'ok') {
      throw StateError('The Camino database is damaged.');
    }
    for (final entry in CaminoSchema.requiredColumns.entries) {
      final columns = await db.rawQuery('PRAGMA table_info("${entry.key}")');
      final names = columns.map((r) => r['name']).toSet();
      final missing = entry.value.where((c) => !names.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw StateError(
          'Database mapping needed: ${entry.key} is missing ${missing.join(', ')}. See README.',
        );
      }
      final id = CaminoSchema.primaryIds[entry.key]!;
      final duplicates = await db.rawQuery(
        'SELECT "$id" FROM "${entry.key}" GROUP BY "$id" HAVING COUNT(*) > 1 OR "$id" IS NULL LIMIT 1',
      );
      if (duplicates.isNotEmpty) {
        throw StateError('Duplicate or null IDs in ${entry.key}.');
      }
    }
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) {
      await (await pending).close();
    }
    _opening = null;
  }
}
