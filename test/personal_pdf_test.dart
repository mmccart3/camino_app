import 'package:image/image.dart' as img;
import 'package:camino_app/services/diary_photos.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:camino_app/services/personal_store.dart';
import 'package:camino_app/services/personal_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'long diary and accented names produce a multipage PDF offline',
    () async {
      final regular = ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
      );
      final bold = ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
      );
      final entries = [
        PersonalEntry(
          category: 'diary',
          kind: 'location',
          sourceId: 1,
          locationId: 1,
          name: 'León — café',
          photos: [
            compressDiaryPhoto(
              img.encodePng(img.Image(width: 200, height: 300)),
            ),
          ],
          locationName: 'León',
          date: '2026-10-11',
          notes: List.filled(
            150,
            'A lovely walking day, with time to rest and reflect.',
          ).join('\n'),
        ),
        const PersonalEntry(
          category: 'favourite',
          kind: 'private',
          sourceId: 2,
          locationId: 2,
          name: 'A saved stay',
          locationName: 'Santiago',
          contact: 'https://example.com/stay?aid=123&label=test\n+34 123456789',
          notes: 'Ask about a quiet room.',
        ),
      ];
      final bytes = await buildPersonalPdf(
        'My Camino diary',
        entries,
        regular,
        bold,
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(5000));
      final output = Platform.environment['CAMINO_PDF_SAMPLE'];
      if (output != null) {
        await File(output).writeAsBytes(bytes);
      }
    },
  );
  test('photo copies respect longest-edge limit and are valid JPEGs', () {
    final original = img.Image(width: 800, height: 2000);
    final bytes = compressDiaryPhoto(img.encodePng(original));
    final result = img.decodeJpg(bytes)!;
    expect(result.height, 1600);
    expect(result.width, 640);
  });
}
