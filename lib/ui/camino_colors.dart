import 'package:flutter/material.dart';

/// Shared GPS, route and waypoint colours for the Camino dark theme.
@immutable
class CaminoColors extends ThemeExtension<CaminoColors> {
  /// GPS fix is recent and accurate.
  final Color gpsGood;

  /// GPS fix is old or inaccurate; refresh before relying on guidance.
  final Color gpsStale;

  /// The walking route polyline drawn on the map.
  final Color routeLine;

  /// Outline drawn around the route so it stays visible on any tile colour.
  final Color routeCasing;

  /// Highlight for the next waypoint and "NEXT" labels.
  final Color nextWaypoint;

  /// Off-route warnings.
  final Color offRoute;
  final Color serviceEat, servicePharmacy, serviceShop;

  const CaminoColors({
    required this.gpsGood,
    required this.gpsStale,
    required this.routeLine,
    required this.routeCasing,
    required this.nextWaypoint,
    required this.offRoute,
    this.serviceEat = const Color(0xFFA85A00),
    this.servicePharmacy = const Color(0xFF1E8A47),
    this.serviceShop = const Color(0xFF7A4FA3),
  });

  /// Values currently used across the app (dark theme).
  static const dark = CaminoColors(
    gpsGood: Color(0xFF7EDDA9),
    gpsStale: Color(0xFFF0A35A),
    routeLine: Color(0xFF1F5FAE),
    routeCasing: Color(0xFFFFFFFF),
    nextWaypoint: Color(0xFFF5C75A),
    offRoute: Color(0xFFF4A59A), // same as colorScheme.error
  );

  /// Falls back to [dark] if the extension has not been registered, so a
  /// screen using this never throws during a partial migration.
  static CaminoColors of(BuildContext context) =>
      Theme.of(context).extension<CaminoColors>() ?? dark;

  @override
  CaminoColors copyWith({
    Color? gpsGood,
    Color? gpsStale,
    Color? routeLine,
    Color? routeCasing,
    Color? nextWaypoint,
    Color? offRoute,
    Color? serviceEat,
    Color? servicePharmacy,
    Color? serviceShop,
  }) => CaminoColors(
    gpsGood: gpsGood ?? this.gpsGood,
    gpsStale: gpsStale ?? this.gpsStale,
    routeLine: routeLine ?? this.routeLine,
    routeCasing: routeCasing ?? this.routeCasing,
    nextWaypoint: nextWaypoint ?? this.nextWaypoint,
    offRoute: offRoute ?? this.offRoute,
    serviceEat: serviceEat ?? this.serviceEat,
    servicePharmacy: servicePharmacy ?? this.servicePharmacy,
    serviceShop: serviceShop ?? this.serviceShop,
  );

  @override
  CaminoColors lerp(ThemeExtension<CaminoColors>? other, double t) {
    if (other is! CaminoColors) return this;
    return CaminoColors(
      gpsGood: Color.lerp(gpsGood, other.gpsGood, t)!,
      gpsStale: Color.lerp(gpsStale, other.gpsStale, t)!,
      routeLine: Color.lerp(routeLine, other.routeLine, t)!,
      routeCasing: Color.lerp(routeCasing, other.routeCasing, t)!,
      nextWaypoint: Color.lerp(nextWaypoint, other.nextWaypoint, t)!,
      offRoute: Color.lerp(offRoute, other.offRoute, t)!,
      serviceEat: Color.lerp(serviceEat, other.serviceEat, t)!,
      servicePharmacy: Color.lerp(servicePharmacy, other.servicePharmacy, t)!,
      serviceShop: Color.lerp(serviceShop, other.serviceShop, t)!,
    );
  }
}
