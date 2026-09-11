import 'package:latlong2/latlong.dart' show LatLng;

class MapLinks {
  static bool _invalid(LatLng? destination) =>
      destination == null ||
      !destination.latitude.isFinite ||
      !destination.longitude.isFinite ||
      destination.latitude.abs() > 90 ||
      destination.longitude.abs() > 180 ||
      (destination.latitude == 0 && destination.longitude == 0);

  static String? appleWalkingDirections(LatLng? destination) {
    if (_invalid(destination)) return null;
    return Uri.https('maps.apple.com', '/', {
      'daddr': '${destination!.latitude},${destination.longitude}',
      'dirflg': 'w',
    }).toString();
  }

  static String? walkingDirections(LatLng? destination) {
    if (_invalid(destination)) return null;
    // Google Maps resolves the user's origin; no extra GPS permission is needed
    // in Camino. The destination is the accommodation's stored GPS position.
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination!.latitude},${destination.longitude}',
      'travelmode': 'walking',
      'dir_action': 'navigate',
    }).toString();
  }
}
