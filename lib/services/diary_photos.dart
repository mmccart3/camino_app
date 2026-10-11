import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decode with the platform first (including iPhone HEIC where supported),
/// then keep a bounded JPEG copy, with no original EXIF/GPS metadata.
Future<Uint8List> prepareDiaryPhoto(Uint8List input) async {
  final codec = await ui.instantiateImageCodec(
    input,
    targetWidth: 1600,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('Could not decode photograph');
      }
      return await compute(compressDiaryPhoto, png.buffer.asUint8List());
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Uint8List compressDiaryPhoto(Uint8List png) {
  final decoded = img.decodePng(png);
  if (decoded == null) throw const FormatException('Unsupported photograph');
  final resized = decoded.width > 1600 || decoded.height > 1600
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
        )
      : decoded;
  return img.encodeJpg(resized, quality: 82);
}
