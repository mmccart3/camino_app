import 'dart:typed_data' show BytesBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/personal_store.dart';
import '../services/diary_backup.dart';
import '../services/camino_plan_store.dart';
import 'personal_library.dart' show editPersonalEntry;

class TodayDiaryButton extends StatefulWidget {
  final VoidCallback? onSaved;
  final String label;
  final bool compact;
  const TodayDiaryButton({
    super.key,
    this.onSaved,
    this.label = 'Today’s entry',
    this.compact = false,
  });
  @override
  State<TodayDiaryButton> createState() => _TodayDiaryButtonState();
}

class _TodayDiaryButtonState extends State<TodayDiaryButton> {
  bool busy = false;
  Future<void> open() async {
    setState(() => busy = true);
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final choices = <PersonalEntry>[];
      for (final plan in await CaminoPlanStore.instance.plans()) {
        for (final day in await CaminoPlanStore.instance.days(plan.id)) {
          if (day.route.date == date) {
            choices.add(
              PersonalEntry(
                category: 'diary',
                kind: 'location',
                sourceId: day.endId,
                locationId: day.endId,
                name: '${day.startName} → ${day.endName}',
                locationName: day.endName,
                date: date,
                contact: 'Walking plan: ${plan.name}, day ${day.order + 1}',
              ),
            );
          }
        }
      }
      PersonalEntry? entry;
      if (!mounted) return;
      if (choices.length > 1) {
        entry = await showDialog<PersonalEntry>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Which walking day?'),
            children: [
              for (final choice in choices)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, choice),
                  child: Text('${choice.name}\n${choice.contact}'),
                ),
            ],
          ),
        );
        if (entry == null) return;
      } else {
        entry =
            choices.firstOrNull ??
            PersonalEntry(
              category: 'diary',
              kind: 'journal',
              sourceId: 0,
              locationId: 0,
              name: 'Today’s entry',
              locationName: '',
              date: date,
            );
      }
      final existing = (await PersonalStore.instance.entries())
          .where(
            (e) =>
                e.category == 'diary' &&
                e.date == date &&
                e.kind == entry!.kind &&
                e.sourceId == entry.sourceId &&
                e.name == entry.name,
          )
          .firstOrNull;
      if (!mounted) return;
      await editPersonalEntry(context, existing ?? entry);
      widget.onSaved?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open today’s entry. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? OutlinedButton(
          onPressed: busy ? null : open,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, size: 22),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(busy ? 'Opening…' : widget.label),
              ),
            ],
          ),
        )
      : FilledButton.icon(
          onPressed: busy ? null : open,
          icon: const Icon(Icons.edit_note),
          label: Text(busy ? 'Opening…' : widget.label),
        );
}

class DiaryBackupActions extends StatefulWidget {
  final VoidCallback onRestored;
  const DiaryBackupActions({super.key, required this.onRestored});
  @override
  State<DiaryBackupActions> createState() => _DiaryBackupActionsState();
}

class _DiaryBackupActionsState extends State<DiaryBackupActions> {
  bool busy = false;
  Future<void> run(bool restore) async {
    setState(() => busy = true);
    try {
      if (restore) {
        final file = await FilePicker.pickFile(
          dialogTitle: 'Choose a Camino diary backup',
        );
        if (file == null) return;
        if ((await file.length() ?? 0) > DiaryBackup.maxBytes) {
          throw const FormatException('Backup exceeds 128 MB.');
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (buffer.length + chunk.length > DiaryBackup.maxBytes) {
            throw const FormatException('Backup exceeds 128 MB.');
          }
          buffer.add(chunk);
        }
        final entries = await compute(DiaryBackup.decode, buffer.takeBytes());
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Restore diary backup?'),
            content: Text(
              '${entries.length} entries with their photos. Identical entries are skipped. '
              'Existing entries are never overwritten; changed versions are kept separately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        final added = await DiaryBackup.restore(
          PersonalStore.instance,
          entries,
        );
        widget.onRestored();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Restored $added entries; ${entries.length - added} identical entries skipped.',
              ),
            ),
          );
        }
      } else {
        final bytes = await DiaryBackup.export(PersonalStore.instance);
        final saved = await FilePicker.saveFile(
          fileName:
              'camino-diary-${DateTime.now().toIso8601String().split('T').first}.json',
          bytes: bytes,
          mimeType: 'application/json',
          dialogTitle: 'Save diary backup',
        );
        if (saved != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Diary backup saved, including photos.'),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not complete diary backup/restore. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: busy ? null : () => run(false),
            icon: const Icon(Icons.save_alt),
            label: const Text('Back up diary'),
          ),
          TextButton.icon(
            onPressed: busy ? null : () => run(true),
            icon: const Icon(Icons.restore),
            label: const Text('Restore diary'),
          ),
        ],
      ),
      if (busy) const LinearProgressIndicator(),
    ],
  );
}

class DiaryThumbnail extends StatefulWidget {
  final int entryId;
  final int cover;
  const DiaryThumbnail({super.key, required this.entryId, this.cover = 0});
  @override
  State<DiaryThumbnail> createState() => _DiaryThumbnailState();
}

class _DiaryThumbnailState extends State<DiaryThumbnail> {
  late final Future<Uint8List?> photo = load();
  Future<Uint8List?> load() async {
    final rows = await (await PersonalStore.instance.database).query(
      'diary_photos',
      columns: ['jpeg'],
      where: 'entry_id = ?',
      whereArgs: [widget.entryId],
      orderBy: 'ordinal',
      limit: 1,
      offset: widget.cover,
    );
    return rows.isEmpty ? null : rows.first['jpeg'] as Uint8List;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: photo,
    builder: (context, snapshot) => snapshot.data == null
        ? const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.photo_outlined),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              snapshot.data!,
              width: 64,
              height: 64,
              cacheWidth: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
  );
}
