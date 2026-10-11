import 'dart:typed_data';
import 'diary_photo_editor.dart';
import 'screens.dart' show LocationDetailScreen, AccommodationBrowser;
import 'package:flutter/material.dart';
import '../data/models.dart' hide Row;
import '../data/camino_repository.dart';
import '../data/walking_location_order.dart';
import '../services/personal_store.dart';
import 'personal_pdf_screen.dart';

Future<void> editPersonalEntry(
  BuildContext context,
  PersonalEntry entry,
) async {
  List<Uint8List> photos;
  try {
    photos = entry.id == null
        ? []
        : await PersonalStore.instance.photos(entry.id!);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load diary photos. Please retry.'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  var picking = false;
  final notes = TextEditingController(text: entry.notes);
  var date = DateTime.tryParse(entry.date) ?? DateTime.now();
  var saving = false;
  String? error;
  final route = DialogRoute<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          entry.category == 'diary'
              ? 'Diary: ${entry.name}'
              : 'Save ${entry.name}',
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.category == 'diary')
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(date.toIso8601String().split('T').first),
                    onPressed: saving || picking
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200),
                            );
                            if (picked != null && context.mounted) {
                              setState(() => date = picked);
                            }
                          },
                  ),
                TextField(
                  controller: notes,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 20000,
                  decoration: InputDecoration(
                    labelText: entry.category == 'diary'
                        ? 'Diary entry'
                        : 'Personal note (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (entry.category == 'diary')
                  DiaryPhotoEditor(
                    photos: photos,
                    date: date,
                    enabled: !saving,
                    onChanged: () => setState(() {}),
                    onBusy: (value) => setState(() => picking = value),
                  ),
                if (error != null) Text(error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving || picking ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving || picking
                ? null
                : () async {
                    if (entry.category == 'diary' &&
                        notes.text.trim().isEmpty &&
                        photos.isEmpty) {
                      setState(
                        () => error = 'Please write an entry or add a photo.',
                      );
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await PersonalStore.instance.save(
                        PersonalEntry(
                          id: entry.id,
                          category: entry.category,
                          kind: entry.kind,
                          sourceId: entry.sourceId,
                          locationId: entry.locationId,
                          name: entry.name,
                          locationName: entry.locationName,
                          date: entry.category == 'diary'
                              ? date.toIso8601String().split('T').first
                              : '',
                          notes: notes.text.trim(),
                          contact: entry.contact,
                          photos: entry.category == 'diary' ? photos : null,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        setState(() {
                          saving = false;
                          error = 'Could not save. Please retry.';
                        });
                      }
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  notes.dispose();
}

class PersonalActions extends StatefulWidget {
  final Accommodation? accommodation;
  final Location? location;
  const PersonalActions({super.key, this.accommodation, this.location});
  @override
  State<PersonalActions> createState() => _PersonalActionsState();
}

class _PersonalActionsState extends State<PersonalActions> {
  bool busy = false;
  PersonalEntry? favourite;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  String get kind => widget.accommodation == null
      ? 'location'
      : widget.accommodation is Albergue
      ? 'albergue'
      : 'private';
  int get sourceId => widget.accommodation?.id ?? widget.location!.id;
  Future<void> refresh() async {
    try {
      final entries = await PersonalStore.instance.entries();
      if (mounted) {
        setState(
          () => favourite = entries
              .where(
                (e) =>
                    e.category == 'favourite' &&
                    e.kind == kind &&
                    e.sourceId == sourceId,
              )
              .firstOrNull,
        );
      }
    } catch (_) {
      /* A save attempt presents a retryable error. */
    }
  }

  Future<void> add(String category) async {
    setState(() => busy = true);
    try {
      final a = widget.accommodation;
      final entry = category == 'favourite' && favourite != null
          ? favourite!
          : PersonalEntry(
              category: category,
              kind: kind,
              sourceId: sourceId,
              locationId: a?.locationId ?? widget.location!.id,
              name: a?.name ?? widget.location!.name,
              locationName: widget.location?.name ?? '',
              contact: a == null
                  ? ''
                  : [
                      if (a.address != null) a.address!,
                      ...a.phoneNumbers.map((n) => n.international),
                      if (a.email != null) a.email!,
                      if (a.websiteUrl != null) a.websiteUrl!,
                      if (a.bookingUrl != null) a.bookingUrl!,
                    ].join('\n'),
            );
      await editPersonalEntry(context, entry);
      await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      if (widget.accommodation != null)
        OutlinedButton.icon(
          onPressed: busy ? null : () => add('favourite'),
          icon: Icon(
            favourite == null ? Icons.favorite_border : Icons.favorite,
          ),
          label: Text(
            favourite == null ? 'Save favourite' : 'Favourite / edit note',
          ),
        ),
      OutlinedButton.icon(
        onPressed: busy ? null : () => add('diary'),
        icon: const Icon(Icons.edit_note),
        label: const Text('Add diary entry'),
      ),
    ],
  );
}

class PersonalLibraryScreen extends StatefulWidget {
  final CaminoRepository repository;
  const PersonalLibraryScreen({super.key, required this.repository});
  @override
  State<PersonalLibraryScreen> createState() => _PersonalLibraryScreenState();
}

class _PersonalLibraryScreenState extends State<PersonalLibraryScreen> {
  List<PersonalEntry> entries = [];
  final selected = <int>{};
  String category = 'favourite';
  bool loading = true;
  String? error;
  DateTimeRange? range;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final saved = await PersonalStore.instance.entries();
      final db = await widget.repository.local.database;
      final locations = (await db.query(
        'locations',
      )).map(Location.fromRow).toList();
      final paths = <Path>[];
      for (final stage in await widget.repository.stages()) {
        paths.addAll(await widget.repository.paths(stage.id));
      }
      final ordered = orderWalkingLocations(locations, paths);
      final rank = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
      final names = {for (final l in locations) l.id: l.name};
      final enriched = saved
          .map(
            (e) => PersonalEntry(
              id: e.id,
              category: e.category,
              kind: e.kind,
              sourceId: e.sourceId,
              locationId: e.locationId,
              name: e.name,
              locationName: names[e.locationId] ?? e.locationName,
              date: e.date,
              notes: e.notes,
              contact: e.contact,
              photoCount: e.photoCount,
            ),
          )
          .toList();
      enriched.sort(
        (a, b) => a.category != b.category
            ? a.category.compareTo(b.category)
            : a.category == 'diary'
            ? a.date.compareTo(b.date)
            : (rank[a.locationId] ?? 99999).compareTo(
                rank[b.locationId] ?? 99999,
              ),
      );
      if (mounted) {
        setState(() {
          entries = enriched;
          loading = false;
          error = null;
          selected.retainAll(enriched.map((e) => e.id!));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load your library.';
        });
      }
    }
  }

  Future<void> openPlace(PersonalEntry entry) async {
    try {
      Widget? screen;
      if (entry.kind == 'location') {
        final location = (await widget.repository.locationsByIds({
          entry.sourceId,
        }))[entry.sourceId];
        if (location != null) {
          screen = LocationDetailScreen(
            repository: widget.repository,
            location: location,
          );
        }
      } else {
        final place = await widget.repository.accommodationById(
          entry.kind,
          entry.sourceId,
        );
        if (place != null) {
          final places = <Accommodation>[];
          if (entry.category == 'favourite') {
            for (final saved in entries.where(
              (e) => e.category == 'favourite',
            )) {
              final item = await widget.repository.accommodationById(
                saved.kind,
                saved.sourceId,
              );
              if (item != null) places.add(item);
            }
          } else {
            places.add(place);
          }
          screen = AccommodationBrowser(places: places, initial: place);
        }
      }
      if (!mounted) return;
      if (screen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This place is no longer listed here. Your saved notes are still available.',
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => screen!),
        );
        await load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this place. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> remove(PersonalEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          entry.category == 'diary'
              ? 'Delete diary entry?'
              : 'Remove favourite?',
        ),
        content: Text(entry.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await PersonalStore.instance.delete(entry.id!);
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = entries
        .where(
          (e) =>
              e.category == category &&
              (category != 'diary' ||
                  range == null ||
                  (e.date.compareTo(
                            range!.start.toIso8601String().split('T').first,
                          ) >=
                          0 &&
                      e.date.compareTo(
                            range!.end.toIso8601String().split('T').first,
                          ) <=
                          0)),
        )
        .toList();
    final chosen = visible.where((e) => selected.contains(e.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites & diary'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'favourite',
                    label: Text('Favourites'),
                    icon: Icon(Icons.favorite),
                  ),
                  ButtonSegment(
                    value: 'diary',
                    label: Text('Diary'),
                    icon: Icon(Icons.book_outlined),
                  ),
                ],
                selected: {category},
                onSelectionChanged: (v) => setState(() {
                  category = v.single;
                  selected.clear();
                }),
              ),
            ),
            if (category == 'diary')
              Wrap(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      range == null
                          ? 'Filter by date'
                          : '${range!.start.toIso8601String().split('T').first} to ${range!.end.toIso8601String().split('T').first}',
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                        initialDateRange: range,
                      );
                      if (picked != null && mounted) {
                        setState(() => range = picked);
                      }
                    },
                  ),
                  if (range != null)
                    TextButton(
                      onPressed: () => setState(() => range = null),
                      child: const Text('Clear filter'),
                    ),
                ],
              ),
            if (error != null)
              TextButton(onPressed: load, child: Text('$error Retry')),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          category == 'diary'
                              ? 'Add diary entries from a location or accommodation page.'
                              : 'Save favourites from accommodation pages.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final e = visible[i];
                        return Card(
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: selected.contains(e.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    selected.add(e.id!);
                                  } else {
                                    selected.remove(e.id);
                                  }
                                }),
                                title: Text(e.name),
                                subtitle: Text(
                                  [
                                    if (e.date.isNotEmpty) e.date,
                                    e.locationName,
                                    if (e.notes.isNotEmpty) e.notes,
                                    if (e.photoCount > 0)
                                      '${e.photoCount} photo(s) — tap Edit to view',
                                  ].join('\n'),
                                ),
                              ),
                              Wrap(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => openPlace(e),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open place'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                    onPressed: () async {
                                      await editPersonalEntry(context, e);
                                      await load();
                                    },
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remove'),
                                    onPressed: () => remove(e),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(
              chosen.isEmpty
                  ? 'Preview PDF — all shown'
                  : 'Preview PDF — ${chosen.length} selected',
            ),
            onPressed: visible.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PersonalPdfScreen(
                        title: category == 'diary'
                            ? 'My Camino diary'
                            : 'My accommodation favourites',
                        entries: chosen.isEmpty ? visible : chosen,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
