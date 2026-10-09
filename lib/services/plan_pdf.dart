import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'plan_pdf_data.dart';
import 'walking_day.dart';
import 'walking_time.dart';

class PlanPdfOptions {
  final bool includeReferences, includeNotes;
  const PlanPdfOptions({
    this.includeReferences = true,
    this.includeNotes = true,
  });
}

class PlanPdf {
  static String filename(String title) {
    final name = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${name.isEmpty ? "camino-plan" : name.substring(0, name.length > 70 ? 70 : name.length)}.pdf';
  }

  static Future<Uint8List> build(
    PlanPdfData data, {
    required ByteData regularFont,
    required ByteData boldFont,
    PlanPdfOptions options = const PlanPdfOptions(),
    DateTime? generatedAt,
  }) async {
    if (data.days.isEmpty) {
      throw ArgumentError('Add a day before sharing your plan.');
    }
    final date = (generatedAt ?? DateTime.now())
        .toIso8601String()
        .split('T')
        .first;
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFont),
      bold: pw.Font.ttf(boldFont),
    );
    final doc = pw.Document(
      title: data.title,
      author: 'Saint Jean to Santiago',
      theme: theme,
    );
    const blue = PdfColor.fromInt(0xff073669),
        yellow = PdfColor.fromInt(0xffffd34d);
    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: blue,
        ),
      ),
    );
    pw.Widget line(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: blue),
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xfff1f5fa),
          ),
          cellPadding: const pw.EdgeInsets.all(7),
          border: null,
          cellAlignment: pw.Alignment.topLeft,
        );
    void add(List<pw.Widget> content) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          maxPages: 100,
          header: (c) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 18),
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: blue),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SAINT JEAN TO SANTIAGO',
                  style: pw.TextStyle(
                    color: yellow,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'MY CAMINO PLAN',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          footer: (c) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated $date',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Page ${c.pageNumber} of ${c.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          build: (c) => content,
        ),
      );
    }

    if (data.days.length > 1) {
      final metres = data.days.fold<double>(
        0,
        (sum, d) => sum + (d.day.metres ?? 0),
      );
      final seconds = data.days.fold<int>(
        0,
        (sum, d) => sum + (d.day.seconds ?? 0),
      );
      add([
        pw.Text(
          data.title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: blue,
          ),
        ),
        heading('Your itinerary at a glance'),
        line(
          '${data.days.length} days | ${(metres / 1000).toStringAsFixed(1)} km | ${WalkingTime.format(Duration(seconds: seconds))} walking',
        ),
        line(
          'Totals include only days with saved estimates. Dates and times use local Camino time.',
        ),
        table(
          ['Day / date', 'Route', 'Distance', 'Walking', 'Stay'],
          [
            for (var i = 0; i < data.days.length; i++)
              [
                '${i + 1}\n${data.days[i].day.route.date ?? "Undated"}',
                '${data.days[i].day.startName} to ${data.days[i].day.endName}',
                data.days[i].day.metres == null
                    ? 'Unavailable'
                    : '${(data.days[i].day.metres! / 1000).toStringAsFixed(1)} km',
                data.days[i].day.seconds == null
                    ? 'Unavailable'
                    : WalkingTime.format(
                        Duration(seconds: data.days[i].day.seconds!),
                      ),
                data.days[i].day.stay == null
                    ? 'Not chosen'
                    : '${data.days[i].day.stay!.name}\n${data.days[i].day.stay!.status}',
              ],
          ],
        ),
        heading('About this copy'),
        line(
          'This PDF is a snapshot of your plan, not a booking confirmation. Generate a new copy after changing your plan. Walking and arrival times are estimates.',
        ),
      ]);
    }
    for (var i = 0; i < data.days.length; i++) {
      final detail = data.days[i], day = detail.day, stay = day.stay;
      final content = <pw.Widget>[
        pw.Text(
          data.title,
          style: const pw.TextStyle(fontSize: 11, color: blue),
        ),
        heading('Day ${i + 1} | ${day.route.date ?? "Date not set"}'),
        pw.Text(
          '${day.startName} to ${day.endName}',
          style: pw.TextStyle(
            fontSize: 23,
            fontWeight: pw.FontWeight.bold,
            color: blue,
          ),
        ),
        pw.SizedBox(height: 12),
        line(
          day.hasEstimate
              ? '${(day.metres! / 1000).toStringAsFixed(2)} km | ${WalkingTime.format(Duration(seconds: day.seconds!))} walking'
              : 'Distance and walking time: estimates unavailable',
        ),
        line('Flat-ground pace: ${day.route.pace.toStringAsFixed(1)} km/h'),
        line(
          'Departure: ${walkingDayClock(day.route.departureMinutes, Duration.zero)}',
        ),
        line(
          day.hasEstimate
              ? 'Approximate arrival: ${walkingDayClock(day.route.departureMinutes, day.totalDuration)} (includes planned breaks)'
              : 'Arrival estimate unavailable',
        ),
        if (i > 0 && day.warningAfter(data.days[i - 1].day) != null)
          line(day.warningAfter(data.days[i - 1].day)!),
        if (detail.notice != null) line(detail.notice!),
        if (detail.stops.isNotEmpty) ...[
          heading('Places and planned breaks'),
          table(
            ['Location', 'Arrival', 'Break', 'Departure'],
            [
              for (final stop in detail.stops)
                [
                  stop.name,
                  stop.arrival,
                  stop.breakMinutes == 0 ? '-' : '${stop.breakMinutes} min',
                  stop.departure,
                ],
            ],
          ),
        ] else if (detail.breaks.isNotEmpty) ...[
          heading('Planned breaks'),
          for (final pause in detail.breaks) line(pause),
        ],
        heading('Where you plan to stay'),
        if (stay == null)
          line('Accommodation not chosen.')
        else ...[
          line(stay.name),
          line('Booking status: ${stay.status}'),
          if (detail.address != null) line(detail.address!),
          for (final contact in detail.contacts)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.UrlLink(
                destination: contact.url,
                child: pw.Text(
                  '${contact.label}: ${contact.value}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: blue,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (options.includeReferences && stay.reference.isNotEmpty) ...[
            heading('Booking reference'),
            line(stay.reference),
          ],
          if (options.includeNotes && stay.notes.isNotEmpty) ...[
            heading('Notes'),
            // Small paragraphs can flow across pages, even for long pasted notes.
            for (final paragraph in splitNotes(stay.notes)) line(paragraph),
          ],
        ],
        pw.SizedBox(height: 14),
        line(
          'Times are estimates in local Camino time. Accommodation status is recorded by you; this document does not make, confirm or cancel a booking.',
        ),
      ];
      add(content);
    }
    return doc.save();
  }

  static List<String> splitNotes(String text) {
    final result = <String>[];
    for (final line in text.split('\n')) {
      final chars = line.runes.toList();
      if (chars.isEmpty) {
        result.add('');
        continue;
      }
      for (var start = 0; start < chars.length; start += 240) {
        result.add(
          String.fromCharCodes(
            chars.sublist(
              start,
              start + 240 > chars.length ? chars.length : start + 240,
            ),
          ),
        );
      }
    }
    return result;
  }
}
