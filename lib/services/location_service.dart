import 'package:geolocator/geolocator.dart';

class LocationService {
  /// A user-triggered foreground fix; no stream or background location service.
  Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Location is switched off. Enable it in device settings.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is blocked. Enable it in app settings.',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError(
        'Location permission was not granted. You can still browse the route.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}
