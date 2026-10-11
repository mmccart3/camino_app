import 'models.dart';

/// Repeated imports can link the same property to several locations. Collapse
/// only identical names and coordinates within the same accommodation category.
/// Keep the first (lowest-ID) record supplied by the repository, preserving its
/// detail-page identity. Nearby properties and cross-category records stay separate.
List<Accommodation> uniqueMapAccommodation(Iterable<Accommodation> places) {
  final seen = <(Type, String, double, double)>{};
  return places.where((place) {
    final position = place.position;
    final name = place.name.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (position == null || name.isEmpty) return true;
    return seen.add((
      place.runtimeType,
      name,
      position.latitude,
      position.longitude,
    ));
  }).toList();
}
