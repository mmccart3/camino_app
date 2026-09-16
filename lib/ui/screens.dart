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
import 'settings_screen.dart';
import 'widgets.dart';
import 'contact_links.dart';
import 'app_title.dart';
import 'app_logo.dart';
import 'stage_directions.dart';
import 'location_navigation.dart';
import 'location_facilities.dart';

class HomeScreen extends StatelessWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  const HomeScreen({
    super.key,
    required this.repository,
    required this.settings,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppTitle(compact: true),
      backgroundColor: caminoBlue,
      foregroundColor: caminoYellow,
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () =>
              navigate(context, SettingsScreen(settings: settings)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AppLogo(),
        const SizedBox(height: 24),
        Text(
          'One stage at a time.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text('Your stages, places and route, available on your phone.'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => navigate(
            context,
            StageListScreen(repository: repository, settings: settings),
          ),
          icon: const Icon(Icons.route),
          label: const Text('Explore stages'),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Your Camino guide is stored on this device. Each stage shows whether its route is ready for guidance.',
            ),
          ),
        ),
        const Text(
          'Guide text, available route geometry and bundled maps work offline. Accommodation photos and Google Maps may need a connection.',
        ),
      ],
    ),
  );
}

class StageListScreen extends StatefulWidget {
  final CaminoRepository repository;
  final SettingsService settings;
  const StageListScreen({
    super.key,
    required this.repository,
    required this.settings,
  });
  @override
  State<StageListScreen> createState() => _StageListScreenState();
}

class _StageListScreenState extends State<StageListScreen> {
  late final future = widget.repository.stages();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stages')),
    body: DataView(
      future: future,
      builder: (stages) => stages.isEmpty
          ? const Center(child: Text('No stages in this database.'))
          : ListView.builder(
              itemCount: stages.length,
              itemBuilder: (context, index) {
                final stage = stages[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${stage.id}')),
                  title: Text(stage.name),
                  subtitle: Text(
                    stage.distanceMeters == null
                        ? 'Distance not recorded'
                        : '${(stage.distanceMeters! / 1000).toStringAsFixed(1)} km',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => navigate(
                    context,
                    StageDetailScreen(
                      repository: widget.repository,
                      settings: widget.settings,
                      stage: stage,
                    ),
                  ),
                );
              },
            ),
    ),
  );
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
  State<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends State<StageDetailScreen> {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.stage.name)),
    body: DataView(
      future: future,
      builder: (route) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.stage.distanceMeters != null)
            Text(
              '${(widget.stage.distanceMeters! / 1000).toStringAsFixed(1)} km · published stage distance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          const SizedBox(height: 12),
          Text(
            route.locationsOrdered
                ? 'Places along the way'
                : 'Locations associated with this stage (order unverified)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (route.locations.isEmpty)
            const Text('No locations for this stage.'),
          for (final location in route.locations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(location.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigate(
                context,
                LocationDetailScreen(
                  repository: widget.repository,
                  location: location,
                ),
              ),
            ),
          ...[
            const SizedBox(height: 20),
            const Text('Published stage map'),
            PublishedImage(
              assetPath: StageImageAssets.map(widget.stage.id),
              title: 'Published stage map',
              hotspots: hotspots,
              onLocationTap: (location) => navigate(
                context,
                LocationDetailScreen(
                  repository: widget.repository,
                  location: location,
                ),
              ),
            ),
          ],
          ...[
            const SizedBox(height: 20),
            const Text('Published elevation chart'),
            PublishedImage(
              assetPath: StageImageAssets.elevation(widget.stage.id),
              title: 'Published elevation chart',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => navigate(
              context,
              MapScreen(
                repository: widget.repository,
                settings: widget.settings,
                stage: widget.stage,
              ),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Route & guidance'),
          ),
          const SizedBox(height: 16),
          StageDirections(route: route),
          const SizedBox(height: 16),
          if (route.canGuide)
            const Text('Full-stage track geometry is available.')
          else ...[
            const Text('Route data needs attention:'),
            for (final issue in route.issues) Text('• $issue'),
          ],
          const SizedBox(height: 20),
          if (widget.stage.nextStageId != null && widget.stage.nextStageId! > 0)
            OutlinedButton(
              onPressed: () => openStage(widget.stage.nextStageId!),
              child: Text('Next stage · ${widget.stage.nextStageId}'),
            ),
          if (widget.stage.alternativeNextStageId != null &&
              widget.stage.alternativeNextStageId! > 0)
            OutlinedButton(
              onPressed: () => openStage(widget.stage.alternativeNextStageId!),
              child: Text(
                'Alternative next stage · ${widget.stage.alternativeNextStageId}',
              ),
            ),
        ],
      ),
    ),
  );
}

class LocationDetailScreen extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  const LocationDetailScreen({
    super.key,
    required this.repository,
    required this.location,
  });
  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  late final future = load();
  Future<(List<Paragraph>, List<Albergue>, List<PrivateAccommodation>)>
  load() async => (
    await widget.repository.paragraphs(widget.location.id),
    await widget.repository.albergues(widget.location.id),
    await widget.repository.privateAccommodation(widget.location.id),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.location.name)),
    body: DataView(
      future: future,
      builder: (data) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LocationNavigationButton(
            repository: widget.repository,
            location: widget.location,
          ),
          LocationFacilities(location: widget.location),
          for (final url in widget.location.imageUrls) DatabaseImage(url),
          const SizedBox(height: 12),
          for (final paragraph in data.$1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paragraph.body),
                  if (paragraph.websiteUrl != null &&
                      SafeLinks.isSafe(paragraph.websiteUrl!))
                    ExternalLinkButton(
                      url: paragraph.websiteUrl!,
                      label: 'More information',
                    ),
                ],
              ),
            ),
          Text('Albergues', style: Theme.of(context).textTheme.titleLarge),
          if (data.$2.isEmpty) const Text('No albergues listed.'),
          for (final place in data.$2)
            ListTile(
              title: Text(place.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  navigate(context, AlbergueDetailScreen(albergue: place)),
            ),
          const SizedBox(height: 16),
          Text(
            'Private accommodation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (data.$3.isEmpty) const Text('No private accommodation listed.'),
          for (final place in data.$3)
            ListTile(
              title: Text(place.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigate(
                context,
                PrivateAccommodationDetailScreen(accommodation: place),
              ),
            ),
        ],
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
    appBar: AppBar(title: Text(place.name)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final url in place.imageUrls) DatabaseImage(url),
        Text(kind, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        if (place.address != null) Text(place.address!),
        if (place.description != null) Text(place.description!),
        ContactLinks(place: place),
        if (place.bookingUrl != null &&
            SafeLinks.isSafe(place.bookingUrl!)) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExternalLinkButton(
              url: place.bookingUrl!,
              label: 'Open booking website',
            ),
          ),
          Text(
            Uri.parse(place.bookingUrl!).queryParameters.containsKey('aid')
                ? 'External affiliate link. Availability and booking require a connection.'
                : 'Availability and booking require a connection.',
          ),
        ] else
          const Text('No booking link is listed.'),
        if (place.singleRateMin != null)
          Text('Single rate from €${place.singleRateMin!.toStringAsFixed(2)}'),
        if (place.singleRateMax != null)
          Text('Single rate up to €${place.singleRateMax!.toStringAsFixed(2)}'),
        if (place.doubleRateMin != null)
          Text('Double rate from €${place.doubleRateMin!.toStringAsFixed(2)}'),
        if (place.doubleRateMax != null)
          Text('Double rate up to €${place.doubleRateMax!.toStringAsFixed(2)}'),
        if (place.rateNotes != null) Text(place.rateNotes!),
        if (place is Albergue) ...[
          AlbergueFacilities(albergue: place as Albergue),
          if ((place as Albergue).openingPeriod != null)
            Text('Opening period: ${(place as Albergue).openingPeriod}'),
          if ((place as Albergue).checkInTimes != null)
            Text('Check-in: ${(place as Albergue).checkInTimes}'),
        ],
        const SizedBox(height: 12),
      ],
    ),
  );
}

class ExternalLinkButton extends StatelessWidget {
  final String url, label;
  const ExternalLinkButton({super.key, required this.url, required this.label});
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
    label: Text(label),
  );
}
