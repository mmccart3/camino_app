import 'place_map.dart';
import 'detail_pager.dart';
import 'personal_library.dart';
import '../services/ahead_of_me.dart';
import '../services/walking_time.dart';
export 'stage_list_screen.dart' show StageListScreen;
import 'ahead_screen.dart';
export 'home_screen.dart' show HomeScreen;
import '../services/recent_walk.dart';
import 'location_plan_button.dart';
import 'accommodation_comparison.dart';
import 'planned_stay.dart';
import '../data/stage_image_assets.dart';
import 'published_image.dart';
import 'albergue_facilities.dart';
import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../data/route_assembler.dart';
import '../services/settings_service.dart';
import '../services/safe_links.dart';
import 'map_screen.dart';
import 'widgets.dart';
import 'contact_links.dart';
import 'stage_directions.dart';
import 'location_navigation.dart';
import 'location_facilities.dart';
import 'location_links.dart';
import 'elevation_screen.dart';

// Keep detailed source notes in the database, but show a concise assumption label.
String _accommodationTimeLabel(String value) {
  if (!value.toLowerCase().contains('assumed')) return value;
  var label = value.replaceAll(
    RegExp(r'\(assumed[^)]*\)', caseSensitive: false),
    '',
  );
  label = label.split(';').first.replaceAll(RegExp(r'\s+'), ' ').trim();
  return '$label (assumed)';
}

class StageDetailScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  const StageDetailScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
  });
  @override
  State<StageDetailScreen> createState() => _StageBrowserState();
}

class _StageBrowserState extends State<StageDetailScreen> {
  @override
  void initState() {
    super.initState();
    RecentWalk.save(widget.stage.id, map: false).ignore();
  }

  late final future = widget.repository.stages();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Stage>>(
    future: future,
    builder: (context, snapshot) {
      final stages = snapshot.data ?? [widget.stage];
      final index = stages.indexWhere((s) => s.id == widget.stage.id);
      final items = index < 0 ? [widget.stage] : stages;
      // Keep the same pager while data loads so it starts at the requested stage.
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return DetailPager<Stage>(
        items: items,
        initialIndex: index < 0 ? 0 : index,
        label: (s) => '${s.displayNumber}: ${s.name}',
        onChanged: (s) => RecentWalk.save(s.id, map: false).ignore(),
        builder: (s) => _StageDetailPage(
          key: ValueKey(s.id),
          repository: widget.repository,
          settings: widget.settings,
          stage: s,
        ),
      );
    },
  );
}

class LocationDetailScreen extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  final List<Location>? sequence;
  const LocationDetailScreen({
    super.key,
    required this.repository,
    required this.location,
    this.sequence,
  });
  @override
  State<LocationDetailScreen> createState() => _LocationBrowserState();
}

class _LocationBrowserState extends State<LocationDetailScreen> {
  late final future = load();
  Future<List<Location>> load() async {
    if (widget.sequence != null) return widget.sequence!;
    final rows = await (await widget.repository.local.database).query(
      'locations',
    );
    final byId = {
      for (final r in rows) Location.fromRow(r).id: Location.fromRow(r),
    };
    final items = <Location>[widget.location];
    final seen = <int>{widget.location.id};
    var current = widget.location;
    while (current.alternativePriorLocationId == null ||
        current.alternativePriorLocationId! <= 0) {
      final prior = byId[current.priorLocationId];
      if (prior == null || !seen.add(prior.id)) break;
      items.insert(0, prior);
      current = prior;
    }
    current = widget.location;
    while (current.alternativeNextLocationId == null ||
        current.alternativeNextLocationId! <= 0) {
      final next = byId[current.nextLocationId];
      if (next == null || !seen.add(next.id)) break;
      items.add(next);
      current = next;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Location>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final sequence = snapshot.data ?? [widget.location];
      final index = sequence.indexWhere((l) => l.id == widget.location.id);
      return DetailPager<Location>(
        items: index < 0 ? [widget.location] : sequence,
        initialIndex: index < 0 ? 0 : index,
        label: (l) => l.name,
        builder: (l) => _LocationDetailPage(
          key: ValueKey(l.id),
          repository: widget.repository,
          location: l,
        ),
      );
    },
  );
}

class AccommodationBrowser extends StatelessWidget {
  final List<Accommodation> places;
  final Accommodation initial;
  const AccommodationBrowser({
    super.key,
    required this.places,
    required this.initial,
  });
  @override
  Widget build(BuildContext context) {
    final index = places.indexWhere(
      (p) => p.id == initial.id && p.runtimeType == initial.runtimeType,
    );
    return DetailPager<Accommodation>(
      items: index < 0 ? [initial] : places,
      initialIndex: index < 0 ? 0 : index,
      label: (p) => p.name,
      builder: (p) => AccommodationDetail(
        key: ValueKey('${p.runtimeType}:${p.id}'),
        place: p,
        kind: p is Albergue ? 'Albergue' : 'Private accommodation',
      ),
    );
  }
}

class _StageDetailPage extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  final Stage stage;
  const _StageDetailPage({
    super.key,
    required this.repository,
    required this.settings,
    required this.stage,
  });
  @override
  State<_StageDetailPage> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends State<_StageDetailPage> {
  @override
  void initState() {
    super.initState();
  }

  late final Future<StageRoute> future = load();
  late final List<MapHotspot> hotspots;
  Future<StageRoute> load() async {
    hotspots = await widget.repository.mapHotspots(widget.stage.id);
    return widget.repository.route(widget.stage);
  }

  Future<void> openStage(int id) async {
    try {
      final stage = await widget.repository.stage(id);
      if (!mounted) {
        return;
      }
      if (stage == null) {
        showFailure(context, 'Stage $id is not available in this database.');
        return;
      }
      navigate(
        context,
        StageDetailScreen(
          repository: widget.repository,
          settings: widget.settings,
          stage: stage,
        ),
      );
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  late final linkedStages = widget.repository.stages();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.stage.name), centerTitle: true),
    body: SafeArea(
      child: DataView(
        future: future,
        builder: (route) {
          final places = route.canGuide
              ? AheadOfMeService().calculate(route, 0, widget.settings.paceKmh)
              : <AheadPlace>[];
          final distances = {for (final p in places) p.location.id: p.metres};
          // Known path distances remain useful even when GPS guidance is blocked.
          if (!route.canGuide && route.locationsOrdered) {
            var metres = 0.0;
            var origin = widget.stage.startLocationId;
            distances[origin] = 0;
            for (final path in route.paths) {
              final length = path.distanceMeters;
              if (path.originLocationId != origin ||
                  length == null ||
                  !length.isFinite ||
                  length < 0) {
                break;
              }
              metres += length;
              distances[path.destinationLocationId] = metres;
              origin = path.destinationLocationId;
            }
          }
          final finish = route.locations
              .where((l) => l.id == widget.stage.finishLocationId)
              .firstOrNull;
          final start = route.locations
              .where((l) => l.id == widget.stage.startLocationId)
              .firstOrNull;
          final time = places
              .where((p) => p.location.id == widget.stage.finishLocationId)
              .firstOrNull
              ?.walkingTime;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Chip(label: Text('Overview')),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                    onPressed: () => navigate(
                      context,
                      MapScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                        stage: widget.stage,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('Elevation'),
                    onPressed: () => navigate(
                      context,
                      ElevationScreen(
                        repository: widget.repository,
                        stage: widget.stage,
                      ),
                    ),
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finish?.name ?? widget.stage.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (start != null) Text('From ${start.name}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text(
                            widget.stage.distanceMeters == null
                                ? 'Distance unavailable'
                                : '${(widget.stage.distanceMeters! / 1000).toStringAsFixed(1)} km',
                          ),
                          Text(
                            time == null
                                ? 'Walking time unavailable'
                                : '${WalkingTime.format(time)} walking',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'At your saved pace of ${widget.settings.paceKmh.toStringAsFixed(1)} km/h',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => navigate(
                  context,
                  MapScreen(
                    repository: widget.repository,
                    settings: widget.settings,
                    stage: widget.stage,
                  ),
                ),
                icon: const Icon(Icons.navigation_outlined),
                label: Text(
                  route.canGuide ? 'Start navigation' : 'View route map',
                ),
              ),
              if (finish != null)
                LocationPlanButton(
                  repository: widget.repository,
                  location: finish,
                  initialStartId: widget.stage.startLocationId,
                ),
              const SizedBox(height: 20),
              Text(
                route.locationsOrdered
                    ? 'Places along the way'
                    : 'Places (order unverified)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (route.locations.isEmpty)
                const Text('No locations for this stage.'),
              for (var i = 0; i < route.locations.length; i++)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      i == route.locations.length - 1
                          ? Icons.flag_outlined
                          : Icons.circle_outlined,
                    ),
                    title: Text(route.locations[i].name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (distances.containsKey(route.locations[i].id) &&
                            route.locations[i].id ==
                                widget.stage.startLocationId)
                          const Text('Start / 0 km')
                        else if (distances[route.locations[i].id] != null)
                          Text(
                            '${(distances[route.locations[i].id]! / 1000).toStringAsFixed(1)} km from start',
                          ),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (route.locations[i].hasBarCafe == true)
                              const Tooltip(
                                message: 'Bar / cafe',
                                child: Icon(
                                  Icons.local_cafe_outlined,
                                  semanticLabel: 'Bar / cafe',
                                ),
                              ),
                            if (route.locations[i].hasPharmacy == true)
                              const Tooltip(
                                message: 'Pharmacy',
                                child: Icon(
                                  Icons.local_pharmacy_outlined,
                                  semanticLabel: 'Pharmacy',
                                ),
                              ),
                            if (route.locations[i].hasGroceryStore == true)
                              const Tooltip(
                                message: 'Groceries',
                                child: Icon(
                                  Icons.shopping_basket_outlined,
                                  semanticLabel: 'Groceries',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => navigate(
                      context,
                      LocationDetailScreen(
                        repository: widget.repository,
                        location: route.locations[i],
                        sequence: route.locationsOrdered
                            ? route.locations
                            : [route.locations[i]],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ExpansionTile(
                key: PageStorageKey('stage-map-${widget.stage.id}'),
                title: const Text('Stage map'),
                leading: const Icon(Icons.map_outlined),
                children: [
                  PublishedImage(
                    assetPath: StageImageAssets.map(widget.stage.id),
                    title: 'Published stage map',
                    hotspots: hotspots,
                    onLocationTap: (location) => navigate(
                      context,
                      LocationDetailScreen(
                        repository: widget.repository,
                        location: location,
                        sequence:
                            route.locationsOrdered &&
                                route.locations.any((l) => l.id == location.id)
                            ? route.locations
                            : [location],
                      ),
                    ),
                  ),
                ],
              ),
              ListTile(
                title: const Text('Elevation'),
                leading: const Icon(Icons.landscape_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => navigate(
                  context,
                  ElevationScreen(
                    repository: widget.repository,
                    stage: widget.stage,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Route & guidance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              OutlinedButton.icon(
                onPressed: () => navigate(
                  context,
                  AheadScreen(
                    repository: widget.repository,
                    settings: widget.settings,
                    stage: widget.stage,
                  ),
                ),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Ahead of me'),
              ),
              StageDirections(route: route),
              const SizedBox(height: 20),
              FutureBuilder<List<Stage>>(
                future: linkedStages,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? <Stage>[];
                  final alternatives = <int>{};
                  for (final parent in all) {
                    if (parent.alternativeNextStageId != null &&
                        (parent.nextStageId == widget.stage.id ||
                            parent.alternativeNextStageId == widget.stage.id)) {
                      alternatives.addAll([
                        if (parent.nextStageId != null) parent.nextStageId!,
                        parent.alternativeNextStageId!,
                      ]);
                    }
                  }
                  alternatives.remove(widget.stage.id);
                  final links = <int, String>{
                    for (final id in alternatives) id: 'Alternative route',
                    if (widget.stage.nextStageId != null &&
                        widget.stage.nextStageId! > 0)
                      widget.stage.nextStageId!: 'Next stage',
                    if (widget.stage.alternativeNextStageId != null &&
                        widget.stage.alternativeNextStageId! > 0)
                      widget.stage.alternativeNextStageId!:
                          'Alternative next stage',
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in links.entries)
                        OutlinedButton(
                          onPressed: () => openStage(entry.key),
                          child: Text(
                            '${entry.value}: ${all.where((s) => s.id == entry.key).firstOrNull?.name ?? 'Stage ${entry.key}'}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _LocationDetailPage extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  const _LocationDetailPage({
    super.key,
    required this.repository,
    required this.location,
  });
  @override
  State<_LocationDetailPage> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<_LocationDetailPage> {
  late final future = load();
  Future<(List<Paragraph>, List<Albergue>, List<PrivateAccommodation>)>
  load() async => (
    await widget.repository.paragraphs(widget.location.id),
    await widget.repository.albergues(widget.location.id),
    await widget.repository.privateAccommodation(widget.location.id),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.location.name), centerTitle: true),
    body: SafeArea(
      child: DataView(
        future: future,
        builder: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PersonalActions(location: widget.location),
            LocationNavigationButton(
              repository: widget.repository,
              location: widget.location,
            ),
            LocationPlanButton(
              repository: widget.repository,
              location: widget.location,
            ),
            const SizedBox(height: 20),
            if (data.$1.isNotEmpty || widget.location.imageUrls.isNotEmpty)
              ExpansionTile(
                title: Text(
                  'About this place',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                leading: const Icon(Icons.info_outline),
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final url in widget.location.imageUrls)
                    DatabaseImage(url),
                  for (final paragraph in data.$1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (paragraph.type != null)
                            Text(
                              paragraph.type!,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          Text(
                            paragraph.body,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (paragraph.websiteUrl != null &&
                              SafeLinks.isSafe(paragraph.websiteUrl!))
                            ExternalLinkButton(
                              url: paragraph.websiteUrl!,
                              label: 'More information',
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            LocationFacilities(location: widget.location),
            PlaceMap(
              position: widget.location.position,
              name: widget.location.name,
              locationId: widget.location.id,
              repository: widget.repository,
              location: widget.location,
            ),
            if (data.$2.isNotEmpty || data.$3.isNotEmpty) ...[
              Text(
                'Where to stay',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a place for booking details or to record your stay.',
              ),
              const SizedBox(height: 12),
              AccommodationComparison(
                places: [...data.$2, ...data.$3],
                onBrowse: (place, shown) => navigate(
                  context,
                  AccommodationBrowser(places: shown, initial: place),
                ),
                onDetails: (place) => navigate(
                  context,
                  AccommodationBrowser(places: [place], initial: place),
                ),
              ),
            ],
            if (data.$2.isEmpty && data.$3.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No accommodation listed here.'),
              ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            LocationLinks(
              repository: widget.repository,
              location: widget.location,
            ),
          ],
        ),
      ),
    ),
  );
}

class AlbergueDetailScreen extends StatelessWidget {
  final Albergue albergue;
  const AlbergueDetailScreen({super.key, required this.albergue});
  @override
  Widget build(BuildContext context) =>
      AccommodationDetail(place: albergue, kind: 'Albergue');
}

class PrivateAccommodationDetailScreen extends StatelessWidget {
  final PrivateAccommodation accommodation;
  const PrivateAccommodationDetailScreen({
    super.key,
    required this.accommodation,
  });
  @override
  Widget build(BuildContext context) =>
      AccommodationDetail(place: accommodation, kind: 'Private accommodation');
}

class AccommodationDetail extends StatelessWidget {
  final Accommodation place;
  final String kind;
  const AccommodationDetail({
    super.key,
    required this.place,
    required this.kind,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(place.name), centerTitle: true),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PersonalActions(accommodation: place),
          Text(kind, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prices',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (place.singleRateMin != null)
                    Text(
                      'Single rate from \u20ac${place.singleRateMin!.toStringAsFixed(2)}',
                    ),
                  if (place.singleRateMax != null)
                    Text(
                      'Single rate up to \u20ac${place.singleRateMax!.toStringAsFixed(2)}',
                    ),
                  if (place.doubleRateMin != null)
                    Text(
                      'Double rate from \u20ac${place.doubleRateMin!.toStringAsFixed(2)}',
                    ),
                  if (place.doubleRateMax != null)
                    Text(
                      'Double rate up to \u20ac${place.doubleRateMax!.toStringAsFixed(2)}',
                    ),
                  if (place.rateNotes != null) Text(place.rateNotes!),
                  if (place.singleRateMin == null &&
                      place.singleRateMax == null &&
                      place.doubleRateMin == null &&
                      place.doubleRateMax == null)
                    const Text('Prices not listed'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ContactLinks(
            place: place,
            showDirections: false,
            showOther: false,
            showHeading: false,
          ),
          if (place.bookingUrl != null &&
              SafeLinks.isSafe(place.bookingUrl!)) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExternalLinkButton(
                url: place.bookingUrl!,
                label: SafeLinks.isBookingWebsite(place.bookingUrl!)
                    ? 'Open Booking.com webpage'
                    : 'Open booking website',
              ),
            ),
            Text(
              Uri.parse(place.bookingUrl!).queryParameters.containsKey('aid')
                  ? 'External affiliate link. Availability and booking require a connection.'
                  : 'Availability and booking require a connection.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            const Text('No booking link is listed.'),
          const SizedBox(height: 12),
          ContactLinks(
            place: place,
            showPhones: false,
            showOther: false,
            showHeading: false,
          ),
          AddStayToPlanButton(place: place),
          PlaceMap(
            position: place.position,
            name: place.name,
            locationId: place.locationId,
          ),
          const SizedBox(height: 16),
          if (place.address != null) ...[
            Text('Address', style: Theme.of(context).textTheme.titleMedium),
            Text(place.address!),
            const SizedBox(height: 16),
          ],
          if (place is Albergue) ...[
            Text(
              'Opening & check-in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if ((place as Albergue).openingPeriod != null)
              Text(
                'Opening period: ${_accommodationTimeLabel((place as Albergue).openingPeriod!)}',
              ),
            if ((place as Albergue).checkInTimes != null)
              Text(
                'Check-in: ${_accommodationTimeLabel((place as Albergue).checkInTimes!)}',
              ),
            const SizedBox(height: 20),
            Text(
              'Beds & facilities',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            AlbergueFacilities(albergue: place as Albergue),
          ],
          ContactLinks(
            place: place,
            showPhones: false,
            showDirections: false,
            showHeading: false,
          ),
          if (place.description != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('About this accommodation'),
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    place.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (place.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Photos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final url in place.imageUrls) DatabaseImage(url),
          ],
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class ExternalLinkButton extends StatelessWidget {
  final String url, label;
  final double? fontSize;
  const ExternalLinkButton({
    super.key,
    required this.url,
    required this.label,
    this.fontSize,
  });
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      try {
        await SafeLinks.open(url);
      } catch (error) {
        if (context.mounted) {
          showFailure(context, error);
        }
      }
    },
    icon: const Icon(Icons.open_in_new),
    label: Text(
      label,
      style: fontSize == null ? null : TextStyle(fontSize: fontSize),
    ),
  );
}
