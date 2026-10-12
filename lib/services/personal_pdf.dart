import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'personal_store.dart';

Future<Uint8List> buildPersonalPdf(
  String title,
  List<PersonalEntry> entries,
  ByteData regular,
  ByteData bold,
) async {
  final journal =
      entries.isNotEmpty && entries.every((e) => e.category == 'diary');
  entries = List.of(entries);
  if (journal) entries.sort((a, b) => a.date.compareTo(b.date));
  final dates = entries.map((e) => e.date).toSet().toList();
  final photos = <PersonalEntry, List<pw.MemoryImage>>{};
  for (final entry in entries) {
    final bytes =
        entry.photos ??
        (entry.id == null || entry.photoCount == 0
            ? <Uint8List>[]
            : await PersonalStore.instance.photos(entry.id!));
    photos[entry] = bytes.map(pw.MemoryImage.new).toList();
  }
  final doc = pw.Document(
    title: title,
    author: 'Saint Jean to Santiago',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  if (journal) {
    final illustrated = entries.where((e) => photos[e]!.isNotEmpty).firstOrNull;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              color: const PdfColor.fromInt(0xff073669),
              child: pw.Text(
                'My Camino journal',
                style: pw.TextStyle(
                  fontSize: 32,
                  color: const PdfColor.fromInt(0xffffd34d),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Saint Jean to Santiago',
              style: const pw.TextStyle(fontSize: 20),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '${dates.first} - ${dates.last}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text('${dates.length} walking days • ${entries.length} entries'),
            pw.SizedBox(height: 24),
            if (illustrated != null)
              pw.SizedBox(
                width: 515,
                height: 380,
                child: pw.Image(
                  photos[illustrated]![(illustrated.coverPhoto ?? 0).clamp(
                    0,
                    photos[illustrated]!.length - 1,
                  )],
                  fit: pw.BoxFit.contain,
                ),
              ),
            pw.Spacer(),
            pw.Text(
              'Memories, places and photographs from my Camino',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  doc.addPage(
    pw.MultiPage(
      maxPages: 500,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (c) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        margin: const pw.EdgeInsets.only(bottom: 16),
        color: const PdfColor.fromInt(0xff073669),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            color: const PdfColor.fromInt(0xffffd34d),
          ),
        ),
      ),
      footer: (c) => pw.Text(
        'Saint Jean to Santiago | ${c.pageNumber} / ${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      build: (c) => [
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) ...[
          if (journal &&
              entryIndex > 0 &&
              entries[entryIndex - 1].date != entries[entryIndex].date)
            pw.NewPage(),
          if (journal &&
              (entryIndex == 0 ||
                  entries[entryIndex - 1].date != entries[entryIndex].date))
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              color: PdfColors.blue50,
              child: pw.Text(
                'Day ${dates.indexOf(entries[entryIndex].date) + 1} | ${entries[entryIndex].date}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ...entryContent(entries[entryIndex], photos),
        ],
      ],
    ),
  );
  return doc.save();
}

List<pw.Widget> entryContent(
  PersonalEntry e,
  Map<PersonalEntry, List<pw.MemoryImage>> photos,
) => [
  pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
    child: pw.Text(
      e.name,
      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
    ),
  ),
  pw.Text(
    [
      if (e.date.isNotEmpty) e.date,
      if (e.locationName.isNotEmpty) e.locationName,
    ].join(' | '),
  ),
  if (e.category == 'favourite') ...[
    for (final line in e.contact.split('\n'))
      if (line.isNotEmpty)
        if (Uri.tryParse(line)?.scheme == 'https' ||
            Uri.tryParse(line)?.scheme == 'http')
          pw.UrlLink(
            destination: line,
            child: pw.Text(
              line,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
            ),
          )
        else
          pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
  ],
  // Small paragraphs allow long diary entries to flow across pages.
  for (final line in splitPersonalNotes(e.notes))
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
    ),
  for (var i = 0; i < photos[e]!.length; i++)
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 520,
            height: 280,
            child: pw.Image(photos[e]![i], fit: pw.BoxFit.contain),
          ),
          if (i < (e.photoCaptions?.length ?? 0) &&
              e.photoCaptions![i].isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                e.photoCaptions![i],
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
        ],
      ),
    ),
  pw.Divider(color: PdfColors.grey300),
];

List<String> splitPersonalNotes(String notes) {
  final result = <String>[];
  for (final paragraph in notes.split('\n')) {
    for (var i = 0; i < paragraph.length; i += 400) {
      result.add(paragraph.substring(i, (i + 400).clamp(0, paragraph.length)));
    }
  }
  return result;
}
