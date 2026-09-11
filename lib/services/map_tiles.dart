import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

/// Shared for this app session: a denied request must not trigger more loading
/// just because the user opens another stage.
class MapTiles {
  static const userAgent = 'CaminoGuideOfflineMVP/0.1.3';
  static int? blockedStatus;
  static NetworkTileProvider provider() => NetworkTileProvider(
    headers: {if (!kIsWeb) 'User-Agent': userAgent},
    attemptDecodeOfHttpErrorResponses: false,
  );
}
