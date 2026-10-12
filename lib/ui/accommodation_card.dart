import 'planned_stay.dart';
import 'package:flutter/material.dart';
import '../data/models.dart' hide Row;

class AccommodationCard extends StatelessWidget {
  final Accommodation place;
  final String kind;
  final VoidCallback onTap;
  const AccommodationCard({
    super.key,
    required this.place,
    required this.kind,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final rate = accommodationPrice(place);
    final albergue = place is Albergue ? place as Albergue : null;
    final facilities = <(bool?, IconData, String)>[
      (albergue?.communalMeal, Icons.restaurant, 'Communal meal'),
      (albergue?.kitchen, Icons.kitchen_outlined, 'Kitchen'),
      (
        albergue?.washingMachine,
        Icons.local_laundry_service_outlined,
        'Washing machine',
      ),
      (albergue?.dryer, Icons.dry_outlined, 'Dryer'),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(kind),
                        ],
                      );
                      final badge = Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rate,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                      if (constraints.maxWidth < 440 ||
                          MediaQuery.textScalerOf(context).scale(16) > 20) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, const SizedBox(height: 10), badge],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 12),
                          Flexible(child: badge),
                        ],
                      );
                    },
                  ),
                  if (albergue?.openingPeriod != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Opening: ${albergue!.openingPeriod}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            albergue.openingPeriod!.toLowerCase().contains(
                              'temporarily closed',
                            )
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                  if (facilities.any((f) => f.$1 == true)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        for (final f in facilities)
                          if (f.$1 == true)
                            Tooltip(
                              message: f.$3,
                              child: Semantics(
                                label: f.$3,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(f.$2, size: 34),
                                    const SizedBox(height: 4),
                                    Text(
                                      f.$3,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('View details →'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AddStayToPlanButton(place: place),
          ),
        ],
      ),
    );
  }
}

String accommodationPrice(Accommodation place) {
  final single = place.singleRateMin;
  final doubleRate = place.doubleRateMin;
  if (single != null && single > 0) {
    return '${place is Albergue ? "Bed" : "Single room"} from €${single.toStringAsFixed(2)}';
  }
  if (doubleRate != null && doubleRate > 0) {
    return 'Double room from €${doubleRate.toStringAsFixed(2)}';
  }
  return 'Price not listed';
}
