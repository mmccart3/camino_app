import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/services/camino_plan_store.dart';
import 'package:camino_app/services/walking_day_store.dart';
import 'package:camino_app/services/plan_pdf.dart';
import 'package:camino_app/services/plan_pdf_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData regular, bold;
  setUpAll(() async {
    regular = ByteData.sublistView(
      await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
    );
    bold = ByteData.sublistView(
      await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
    );
  });
  PlanPdfDay day(
    int index, {
    bool estimated = true,
    String? notes,
  }) => PlanPdfDay(
    ItineraryDay(
      id: index,
      planId: 1,
      order: index,
      startId: 1,
      endId: 2,
      startName: 'Saint Jean Pied de Port',
      endName: 'Roncesvalles via Orisson',
      metres: estimated ? 24900 : null,
      seconds: estimated ? 26100 : null,
      route: SavedWalkingDay(
        'day$index',
        estimated ? [1, 2] : [],
        4.2,
        '2027-05-${index.toString().padLeft(2, '0')}',
        departureMinutes: 480,
        breaks: {3: 30},
      ),
      stay: PlannedStay(
        id: 7,
        kind: 'albergue',
        name: 'Refuge Orisson',
        status: 'Confirmed',
        reference: 'PRIVATE-REF-123',
        notes:
            notes ??
            'PRIVATE-NOTE: Vegetarian meal requested. Price EUR 45. Meet Jos\u00e9 at reception.',
      ),
    ),
    stops: estimated
        ? [
            const PlanPdfStop('Saint Jean Pied de Port', '08:00', '08:00', 0),
            const PlanPdfStop('Huntto', '09:25', '09:25', 0),
            const PlanPdfStop('Orisson', '10:15', '10:45', 30),
            const PlanPdfStop('Roncesvalles', '15:45', '15:45', 0),
          ]
        : [],
    contacts: [
      const PlanPdfContact('Phone', '+33638269738', 'tel:+33638269738'),
      const PlanPdfContact(
        'Website',
        'Accommodation website',
        'https://www.refuge-orisson.com/',
      ),
      const PlanPdfContact(
        'Booking website',
        'Booking website',
        'https://www.booking.com/hotel/example.html?aid=818289&label=keep+exact',
      ),
    ],
    address: 'Orisson, France',
    notice: estimated ? null : 'No recorded route estimate is available.',
  );
  Future<Uint8List> generate(
    PlanPdfData data, {
    PlanPdfOptions options = const PlanPdfOptions(),
  }) => PlanPdf.build(
    data,
    regularFont: regular,
    boldFont: bold,
    options: options,
    generatedAt: DateTime(2026, 10, 8),
  );
  Future<void> output(String name, Uint8List bytes) async {
    final folder = Platform.environment['CAMINO_PDF_OUTPUT'];
    if (folder != null) {
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.pdf').writeAsBytes(bytes);
    }
  }

  test(
    'defaults include references and notes; filenames cannot escape a folder',
    () {
      expect(const PlanPdfOptions().includeReferences, isTrue);
      expect(const PlanPdfOptions().includeNotes, isTrue);
      expect(PlanPdf.filename('../../Trip: May?'), 'Trip-May.pdf');
    },
  );
  test(
    'creates an itinerary and a redacted PDF, including unknown days',
    () async {
      final data = PlanPdfData('My spring Camino', [
        day(1),
        day(2, estimated: false),
      ]);
      final full = await generate(data);
      final redacted = await generate(
        data,
        options: const PlanPdfOptions(
          includeReferences: false,
          includeNotes: false,
        ),
      );
      expect(String.fromCharCodes(full.take(5)), '%PDF-');
      expect(full.length, greaterThan(redacted.length));
      await output('itinerary', full);
      await output('itinerary_without_private_details', redacted);
    },
  );
  test('long notes and many days paginate without overflowing', () async {
    final bytes = await generate(
      PlanPdfData('Long itinerary', [
        for (var i = 1; i <= 35; i++)
          day(
            i,
            notes: i == 1
                ? List.filled(
                    35,
                    'Long note: arrival details, dietary preferences and room arrangements.',
                  ).join(' ')
                : null,
          ),
      ]),
    );
    expect(bytes.length, greaterThan(10000));
    await output('long_itinerary', bytes);
  });
  test('empty itineraries cannot be exported', () async {
    await expectLater(
      generate(const PlanPdfData('Empty', [])),
      throwsArgumentError,
    );
  });
}
