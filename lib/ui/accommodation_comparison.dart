import 'package:flutter/material.dart';
import '../data/models.dart';
import 'accommodation_card.dart';

bool matchesAccommodation(
  Accommodation place, {
  bool privateRoom = false,
  bool meal = false,
  bool kitchen = false,
}) {
  final hostel = place is Albergue ? place : null;
  final hasRoom =
      place is PrivateAccommodation ||
      (place.doubleRateMin ?? 0) > 0 ||
      (place.doubleRateMax ?? 0) > 0;
  return (!privateRoom || hasRoom) &&
      (!meal || hostel?.communalMeal == true) &&
      (!kitchen || hostel?.kitchen == true);
}

class AccommodationComparison extends StatefulWidget {
  final List<Accommodation> places;
  final ValueChanged<Accommodation> onDetails;
  const AccommodationComparison({
    super.key,
    required this.places,
    required this.onDetails,
  });
  @override
  State<AccommodationComparison> createState() =>
      _AccommodationComparisonState();
}

class _AccommodationComparisonState extends State<AccommodationComparison> {
  bool privateRoom = false, meal = false, kitchen = false;
  @override
  Widget build(BuildContext context) {
    final shown = widget.places
        .where(
          (p) => matchesAccommodation(
            p,
            privateRoom: privateRoom,
            meal: meal,
            kitchen: kitchen,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Private rooms'),
              selected: privateRoom,
              onSelected: (v) => setState(() => privateRoom = v),
            ),
            FilterChip(
              label: const Text('Communal meal'),
              selected: meal,
              onSelected: (v) => setState(() => meal = v),
            ),
            FilterChip(
              label: const Text('Kitchen'),
              selected: kitchen,
              onSelected: (v) => setState(() => kitchen = v),
            ),
          ],
        ),
        if (privateRoom || meal || kitchen)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Showing listed facilities only. Unlisted facilities may still be available.',
            ),
          ),
        Text('${shown.length} of ${widget.places.length} places'),
        if (shown.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No places match these filters.'),
          ),
          if (privateRoom || meal || kitchen)
            TextButton(
              onPressed: () => setState(() {
                privateRoom = false;
                meal = false;
                kitchen = false;
              }),
              child: const Text('Clear filters'),
            ),
        ],
        for (final place in shown)
          AccommodationCard(
            key: ValueKey('${place.runtimeType}:${place.id}'),
            place: place,
            kind: place is Albergue ? 'Albergue' : 'Private accommodation',
            onTap: () => widget.onDetails(place),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Listed prices and opening periods; live bed availability is not shown.',
          ),
        ),
      ],
    );
  }
}
