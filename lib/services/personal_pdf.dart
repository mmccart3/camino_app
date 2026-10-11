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
        for (final e in entries) ...[
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
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blue,
                      ),
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
          for (final photo in photos[e]!)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.SizedBox(
                width: 520,
                height: 300,
                child: pw.Image(photo, fit: pw.BoxFit.contain),
              ),
            ),
          pw.Divider(color: PdfColors.grey300),
        ],
      ],
    ),
  );
  return doc.save();
}

List<String> splitPersonalNotes(String notes) {
  final result = <String>[];
  for (final paragraph in notes.split('\n')) {
    for (var i = 0; i < paragraph.length; i += 400) {
      result.add(paragraph.substring(i, (i + 400).clamp(0, paragraph.length)));
    }
  }
  return result;
}
