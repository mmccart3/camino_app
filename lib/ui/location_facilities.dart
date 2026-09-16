import 'package:flutter/material.dart';
import '../data/models.dart';
import 'screens.dart' show ExternalLinkButton;

class LocationFacilities extends StatelessWidget {
  final Location location;
  const LocationFacilities({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final services = [
      ('hasBarCafe', 'Bar / café', Icons.local_cafe_outlined),
      ('hasPharmacy', 'Pharmacy', Icons.local_pharmacy_outlined),
      ('hasGroceryStore', 'Groceries', Icons.shopping_basket_outlined),
    ].where((service) => location.facility(service.$1) == true).toList();
    if (services.isEmpty) return const SizedBox.shrink();
    final mapped = services.any(
      (service) => (text(location.source, '${service.$1}Source') ?? '')
          .startsWith('OSM reviewed:'),
    );

    Widget facility(String column, String label, IconData icon) {
      final checked = text(location.source, '${column}CheckedAt');
      return Tooltip(
        message: [
          label,
          if (checked != null) 'Checked: ${checked.split('T').first}',
        ].join('\n'),
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Local services', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final service in services)
                facility(service.$1, service.$2, service.$3),
            ],
          ),
          if (mapped)
            const ExternalLinkButton(
              url: 'https://www.openstreetmap.org/copyright',
              label: '© OpenStreetMap contributors',
            ),
        ],
      ),
    );
  }
}
