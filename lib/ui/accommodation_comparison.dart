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
      place is PrivateAccommodation || hostel?.privateRoomsAvailable == true;
  return (!privateRoom || hasRoom) &&
      (!meal || hostel?.communalMeal == true) &&
      (!kitchen || hostel?.kitchen == true);
}

class AccommodationComparison extends StatefulWidget {
  final List<Accommodation> places;
  final ValueChanged<Accommodation> onDetails;
  final void Function(Accommodation, List<Accommodation>)? onBrowse;
  const AccommodationComparison({
    super.key,
    required this.places,
    required this.onDetails,
    this.onBrowse,
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
    int count({bool? room, bool? meals, bool? kitchens}) => widget.places
        .where(
          (p) => matchesAccommodation(
            p,
            privateRoom: room ?? privateRoom,
            meal: meals ?? meal,
            kitchen: kitchens ?? kitchen,
          ),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: Text('All (${widget.places.length})'),
              selected: !privateRoom && !meal && !kitchen,
              onSelected: (_) => setState(() {
                privateRoom = meal = kitchen = false;
              }),
            ),
            FilterChip(
              label: Text('Private rooms (${count(room: true)})'),
              selected: privateRoom,
              onSelected: (v) => setState(() => privateRoom = v),
            ),
            FilterChip(
              label: Text('Communal meal (${count(meals: true)})'),
              selected: meal,
              onSelected: (v) => setState(() => meal = v),
            ),
            FilterChip(
              label: Text('Kitchen (${count(kitchens: true)})'),
              selected: kitchen,
              onSelected: (v) => setState(() => kitchen = v),
            ),
          ],
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
            onTap: () => widget.onBrowse != null
                ? widget.onBrowse!(place, shown)
                : widget.onDetails(place),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Listed prices. Live availability not shown.'),
        ),
      ],
    );
  }
}
