import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/models.dart' hide Row;
import '../services/settings_service.dart';
import 'location_facilities.dart';
import 'camino_colors.dart';
import 'widgets.dart';

/// Database-backed badges do not depend on a basemap or tile POI zoom levels.
class LocationFacilityMapLayer extends StatelessWidget {
  final List<Location> locations;
  final SettingsService settings;
  final ValueChanged<Location> onTap;
  const LocationFacilityMapLayer({
    super.key,
    required this.locations,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final selected = settings.mapFacilities;
        return MarkerLayer(
          markers: [
            for (final location in locations)
              if (location.position != null)
                Marker(
                  point: location.position!,
                  width: zoom >= 12 ? 128 : 88,
                  height: zoom >= 12 ? 88 : 60,
                  alignment: Alignment.topCenter,
                  rotate: true,
                  child: LocationFacilityMarker(
                    location: location,
                    zoom: zoom,
                    highlighted:
                        selected.isEmpty ||
                        selected.any((key) => location.facility(key) == true),
                    onTap: () => onTap(location),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class LocationFacilityMarker extends StatelessWidget {
  final Location location;
  final double zoom;
  final bool highlighted;
  final VoidCallback onTap;
  const LocationFacilityMarker({
    super.key,
    required this.location,
    required this.zoom,
    required this.highlighted,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final services = locationFacilityIcons.where(
      (s) => location.facility(s.$1) == true,
    );
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: highlighted ? 1 : .3,
      child: Tooltip(
        message: location.name,
        child: Semantics(
          button: true,
          label:
              '${location.name}${zoom >= 11 ? ': ${services.map((s) => s.$2).join(', ')}' : ''}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (zoom >= 12)
                    Flexible(
                      child: Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                          backgroundColor: colors.surface,
                        ),
                      ),
                    ),
                  if (zoom >= 11 && services.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: highlighted
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final service in services)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Icon(
                                service.$3,
                                key: ValueKey(
                                  'facility-${location.id}-${service.$1}',
                                ),
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Icon(
                    Icons.place,
                    size: 24,
                    color: CaminoColors.of(context).nextWaypoint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapFacilityFilter extends StatelessWidget {
  final SettingsService settings;
  const MapFacilityFilter({super.key, required this.settings});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => PopupMenuButton<String>(
      tooltip: 'Show facilities',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(
            settings.mapFacilities.isEmpty
                ? 'Show'
                : 'Show (${settings.mapFacilities.length})',
          ),
        ),
      ),
      itemBuilder: (_) => [
        for (final (key, label) in const [
          ('hasBarCafe', 'Cafés / bars'),
          ('hasPharmacy', 'Pharmacies'),
          ('hasGroceryStore', 'Shops'),
        ])
          CheckedPopupMenuItem(
            value: key,
            checked: settings.mapFacilities.contains(key),
            child: Text(label),
          ),
      ],
      onSelected: (key) async {
        try {
          await settings.setMapFacility(
            key,
            !settings.mapFacilities.contains(key),
          );
        } catch (error) {
          if (context.mounted) showFailure(context, error);
        }
      },
    ),
  );
}
