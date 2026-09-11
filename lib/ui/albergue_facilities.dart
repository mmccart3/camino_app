import 'package:flutter/material.dart';
import '../data/models.dart';

class AlbergueFacilities extends StatelessWidget {
  final Albergue albergue;
  const AlbergueFacilities({super.key, required this.albergue});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Dormitories: ${albergue.numberOfDorms ?? "Not recorded"}'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _facility(
            'Washing machine',
            Icons.local_laundry_service_outlined,
            albergue.washingMachine,
          ),
          _facility('Dryer', Icons.dry_outlined, albergue.dryer),
          _facility(
            'Communal meal',
            Icons.restaurant_outlined,
            albergue.communalMeal,
          ),
          _facility(
            'Kitchen facilities',
            Icons.kitchen_outlined,
            albergue.kitchen,
          ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _facility(String label, IconData icon, bool? available) {
    final status = available == null
        ? 'Not recorded'
        : available
        ? 'Yes'
        : 'No';
    return Chip(avatar: Icon(icon, size: 20), label: Text('$label: $status'));
  }
}
