import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/diary_photos.dart';

class DiaryPhotoEditor extends StatefulWidget {
  final List<Uint8List> photos;
  final List<String> captions;
  final int cover;
  final ValueChanged<int> onCoverChanged;
  final bool enabled;
  final DateTime date;
  final VoidCallback onChanged;
  final ValueChanged<bool> onBusy;
  const DiaryPhotoEditor({
    super.key,
    required this.photos,
    required this.captions,
    required this.cover,
    required this.onCoverChanged,
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
          widget.captions.add('');
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

  void move(int from, int to) {
    final photo = widget.photos.removeAt(from);
    final caption = widget.captions.removeAt(from);
    widget.photos.insert(to, photo);
    widget.captions.insert(to, caption);
    widget.onCoverChanged(
      widget.cover == from
          ? to
          : widget.cover == to
          ? from
          : widget.cover,
    );
    widget.onChanged();
    setState(() {});
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
      for (var i = 0; i < widget.photos.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                InkWell(
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
                  child: Image.memory(
                    widget.photos[i],
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                TextFormField(
                  key: ObjectKey(widget.photos[i]),
                  initialValue: widget.captions[i],
                  enabled: !busy && widget.enabled,
                  maxLength: 500,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Photo caption (optional)',
                  ),
                  onChanged: (value) {
                    widget.captions[i] = value;
                  },
                ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: busy || !widget.enabled
                          ? null
                          : () {
                              widget.onCoverChanged(i);
                              widget.onChanged();
                            },
                      icon: Icon(
                        widget.cover == i ? Icons.star : Icons.star_border,
                      ),
                      label: Text(
                        widget.cover == i ? 'Entry cover' : 'Use as cover',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Move earlier',
                      onPressed: busy || !widget.enabled || i == 0
                          ? null
                          : () => move(i, i - 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move later',
                      onPressed:
                          busy ||
                              !widget.enabled ||
                              i == widget.photos.length - 1
                          ? null
                          : () => move(i, i + 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: busy || !widget.enabled
                          ? null
                          : () {
                              widget.photos.removeAt(i);
                              widget.captions.removeAt(i);
                              widget.onCoverChanged(
                                widget.cover == i
                                    ? 0
                                    : widget.cover > i
                                    ? widget.cover - 1
                                    : widget.cover,
                              );
                              widget.onChanged();
                              setState(() {});
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
