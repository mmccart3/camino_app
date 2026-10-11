import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/diary_photos.dart';

class DiaryPhotoEditor extends StatefulWidget {
  final List<Uint8List> photos;
  final bool enabled;
  final DateTime date;
  final VoidCallback onChanged;
  final ValueChanged<bool> onBusy;
  const DiaryPhotoEditor({
    super.key,
    required this.photos,
    required this.enabled,
    required this.date,
    required this.onChanged,
    required this.onBusy,
  });
  @override
  State<DiaryPhotoEditor> createState() => _DiaryPhotoEditorState();
}

class _DiaryPhotoEditorState extends State<DiaryPhotoEditor> {
  bool busy = false;
  String? message;
  Future<void> pick() async {
    setState(() {
      busy = true;
      message = null;
    });
    widget.onBusy(true);
    try {
      final picker = ImagePicker();
      List<XFile> files = [];
      if (Platform.isAndroid) {
        final recovered = await picker.retrieveLostData();
        files = recovered.files ?? [];
        if (recovered.exception != null) throw recovered.exception!;
        if (files.isNotEmpty) {
          message =
              'Recovered your interrupted selection. Check these photos before saving.';
        }
      }
      if (files.isEmpty) {
        files = await picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          requestFullMetadata: false,
        );
      }
      if (!mounted) return;
      final remaining = 12 - widget.photos.length;
      if (files.length > remaining) {
        message =
            'Only the first $remaining selected photos were added (12 per entry).';
      }
      var failed = 0;
      for (final file in files.take(remaining)) {
        try {
          final photo = await prepareDiaryPhoto(await file.readAsBytes());
          if (!mounted) return;
          widget.photos.add(photo);
        } catch (_) {
          failed++;
        }
      }
      if (failed > 0) {
        message = '$failed photo(s) could not be read. Try a JPEG or PNG copy.';
      }
      if (mounted) widget.onChanged();
    } catch (_) {
      if (mounted) {
        message =
            'Could not open the photo library. Check photo access in phone settings and try again.';
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Photos for ${widget.date.toIso8601String().split('T').first}'),
      const Text(
        'Choose that day’s photos from your library. Up to 12 per entry.',
      ),
      if (message != null) Text(message!),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < widget.photos.length; i++)
            SizedBox(
              width: 100,
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (c) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InteractiveViewer(
                                  child: Image.memory(
                                    widget.photos[i],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: Image.memory(widget.photos[i], fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton.filled(
                      tooltip: 'Remove photo ${i + 1}',
                      onPressed: busy || !widget.enabled
                          ? null
                          : () {
                              widget.photos.removeAt(i);
                              widget.onChanged();
                              setState(() {});
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      OutlinedButton.icon(
        onPressed: busy || !widget.enabled || widget.photos.length >= 12
            ? null
            : pick,
        icon: Icon(
          busy ? Icons.hourglass_top : Icons.add_photo_alternate_outlined,
        ),
        label: Text(busy ? 'Preparing photos…' : 'Add photos'),
      ),
    ],
  );
}
