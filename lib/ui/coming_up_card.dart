import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../data/camino_repository.dart';
import '../data/models.dart' hide Row;
import '../data/route_assembler.dart';
import '../services/ahead_of_me.dart';
import '../services/next_services.dart';
import '../services/route_guidance.dart';
import '../services/settings_service.dart';
import '../services/walking_day.dart';
import '../services/walking_time.dart';
import 'ahead_screen.dart';
import 'camino_colors.dart';
import 'widgets.dart';

/// Session cache belongs to the repository, not a global database singleton.
final _routes = Expando<Map<int, Future<StageRoute>>>();

class ComingUpCard extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  final WalkingDay? day;
  final LatLng? position;
  const ComingUpCard({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
    this.day,
    this.position,
  });
  @override
  State<ComingUpCard> createState() => _ComingUpCardState();
}

class _ComingUpCardState extends State<ComingUpCard> {
  StageRoute? route;
  NextServices? services;
  int revision = 0;
  late double pace;
  @override
  void initState() {
    super.initState();
    pace = widget.settings.paceKmh;
    widget.settings.addListener(speedChanged);
    scheduleLoad();
  }

  void scheduleLoad() {
    final token = ++revision;
    route = null;
    services = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load(token);
    });
  }

  @override
  void didUpdateWidget(ComingUpCard old) {
    super.didUpdateWidget(old);
    if (old.settings != widget.settings) {
      old.settings.removeListener(speedChanged);
      widget.settings.addListener(speedChanged);
    }
    if (old.repository != widget.repository ||
        old.stage.id != widget.stage.id ||
        old.day != widget.day) {
      scheduleLoad();
    } else if (old.position != widget.position ||
        pace != widget.settings.paceKmh) {
      calculate();
    }
  }

  void speedChanged() {
    if (pace == widget.settings.paceKmh) return;
    setState(calculate);
  }

  void calculate() {
    pace = widget.settings.paceKmh;
    services = null;
    final r = route;
    if (r == null || !r.canGuide) return;
    var index = 0;
    if (widget.position != null) {
      final g = RouteGuidanceService().calculate(
        r.points,
        widget.position!,
        pace,
      );
      if (g == null || g.offRouteMeters > 150) return;
      index = r.points.indexWhere((p) => p.id == g.nearestTrackPoint.id);
      if (index < 0) return;
    }
    services = NextServices.from(AheadOfMeService().calculate(r, index, pace));
  }

  Future<void> load(int token) async {
    try {
      StageRoute loaded;
      final day = widget.day;
      if (day != null) {
        if (day.joinMetres > 0 || day.legs.isEmpty) return;
        loaded = StageRoute(
          stage: widget.stage,
          paths: day.legs.map((l) => l.path).toList(),
          locations: day.places,
          segments: day.legs.map((l) => l.points).toList(),
          points: day.guidancePoints,
          issues: [],
          locationsOrdered: true,
        );
      } else {
        final cache = _routes[widget.repository] ??= {};
        loaded = await (cache[widget.stage.id] ??= widget.repository.route(
          widget.stage,
        ));
      }
      if (!mounted || token != revision) return;
      setState(() {
        route = loaded;
        calculate();
      });
    } catch (_) {
      // Failure stays silent. Allow a later visit to retry rather than cache it.
      _routes[widget.repository]?.remove(widget.stage.id);
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(speedChanged);
    super.dispose();
  }

  void open(String filter) => navigate(
    context,
    AheadScreen(
      repository: widget.repository,
      settings: widget.settings,
      stage: widget.stage,
      initialRoute: route,
      initialFilter: filter,
      initialPosition: widget.position,
      previewFromStart: widget.position == null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final next = services;
    if (next == null) return const SizedBox.shrink();
    final colors = CaminoColors.of(context);
    final end =
        route!.locations
            .where((l) => l.id == route!.paths.last.destinationLocationId)
            .firstOrNull
            ?.name ??
        'stage end';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.position == null
                  ? "Along today's route"
                  : 'Coming up on your route',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (next.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nothing recorded for the rest of this stage. Carry food and water.',
                ),
              )
            else ...[
              serviceRow(
                next.cafe,
                'Café',
                'Cafe or bar',
                Icons.local_cafe,
                colors.serviceEat,
                end,
              ),
              serviceRow(
                next.pharmacy,
                'Pharmacy',
                'Pharmacy',
                Icons.local_pharmacy,
                colors.servicePharmacy,
                end,
              ),
              serviceRow(
                next.shop,
                'Groceries',
                'Shop',
                Icons.shopping_basket,
                colors.serviceShop,
                end,
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => open('All'),
                child: const Text('See all ahead'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget serviceRow(
    AheadPlace? place,
    String filter,
    String label,
    IconData icon,
    Color color,
    String end,
  ) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: label,
      child: InkWell(
        onTap: () => open(filter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: place == null
                        ? Theme.of(context).colorScheme.outline
                        : color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(icon, size: 21, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: place == null
                      ? Text(
                          'None recorded before $end',
                          style: TextStyle(color: muted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.location.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${place.metres == null ? "Distance unavailable" : "${(place.metres! / 1000).toStringAsFixed(1)} km"} · ${place.walkingTime == null ? "Time unavailable" : WalkingTime.format(place.walkingTime!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
