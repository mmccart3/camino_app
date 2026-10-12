import 'package:flutter/material.dart';
import '../data/models.dart' hide Row;

class AlbergueFacilities extends StatelessWidget {
  final Albergue albergue;
  const AlbergueFacilities({super.key, required this.albergue});
  @override
  Widget build(BuildContext context) {
    final facilities = <(String, IconData, bool?)>[
      (
        'Washing machine',
        Icons.local_laundry_service_outlined,
        albergue.washingMachine,
      ),
      ('Dryer', Icons.dry_outlined, albergue.dryer),
      ('Communal meal', Icons.restaurant_outlined, albergue.communalMeal),
      ('Kitchen', Icons.kitchen_outlined, albergue.kitchen),
    ];
    Widget chip((String, IconData, bool?) f) => Chip(
      avatar: Icon(
        f.$3 == true ? f.$2 : Icons.close,
        size: 24,
        color: f.$3 == true
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      label: Text('${f.$1}: ${f.$3 == true ? "Yes" : "No"}'),
      side: BorderSide(
        color: f.$3 == true
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            if (albergue.numberOfBeds != null)
              _stat(Icons.bed_outlined, '${albergue.numberOfBeds} beds'),
            if (albergue.numberOfDorms != null)
              _stat(
                Icons.meeting_room_outlined,
                '${albergue.numberOfDorms} dormitories',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: facilities.where((f) => f.$3 == true).map(chip).toList(),
        ),
        if (facilities.any((f) => f.$3 != true))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Not available'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: facilities
                      .where((f) => f.$3 != true)
                      .map(chip)
                      .toList(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _stat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    ],
  );
}
