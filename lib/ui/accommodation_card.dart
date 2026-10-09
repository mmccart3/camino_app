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
    final single = place.singleRateMin;
    final doubleRate = place.doubleRateMin;
    final rate = single != null && single > 0
        ? '${place is Albergue ? "Bed" : "Single room"} from \u20ac${single.toStringAsFixed(2)} ${place is Albergue ? "per bed" : "per room"}'
        : doubleRate != null && doubleRate > 0
        ? 'Double room from \u20ac${doubleRate.toStringAsFixed(2)} per room'
        : null;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(kind),
              if (rate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    rate,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (rate == null) const Text('Price not listed'),
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
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: onTap,
                    child: const Text('View details'),
                  ),
                  AddStayToPlanButton(place: place),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
