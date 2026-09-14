import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/route_assembler.dart';
import '../services/navigation_session.dart';
import '../services/settings_service.dart';
import 'widgets.dart';

const batteryWarning =
    'Screen-locked navigation uses continuous high-accuracy GPS and can heavily drain your battery. Start with enough charge and stop the session when you finish walking. Alerts may be delayed by poor GPS, battery-saving settings, or phone notification settings. Force-closing the app stops tracking.';

class AlertDistanceSetting extends StatefulWidget {
  final SettingsService settings;
  const AlertDistanceSetting({super.key, required this.settings});
  @override
  State<AlertDistanceSetting> createState() => _AlertDistanceSettingState();
}

class _AlertDistanceSettingState extends State<AlertDistanceSetting> {
  late double value = widget.settings.offRouteMetres;
  bool saving = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Off-route alert distance: ${value.round()} metres'),
      Slider(
        value: value,
        min: 20,
        max: 500,
        divisions: 48,
        label: '${value.round()} m',
        onChanged: saving ? null : (v) => setState(() => value = v),
      ),
      TextButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await widget.settings.setOffRouteMetres(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Alert distance saved. Applies to the next walking session.',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) showFailure(context, error);
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: Text(saving ? 'Saving…' : 'Save alert distance'),
      ),
      const Text(
        'Alerts are off until you start a walking session from a stage map.',
      ),
    ],
  );
}

class WalkingAlertControls extends StatelessWidget {
  final StageRoute route;
  final SettingsService settings;
  const WalkingAlertControls({
    super.key,
    required this.route,
    required this.settings,
  });
  @override
  Widget build(BuildContext context) {
    final session = NavigationSession.instance;
    if (!session.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Screen-locked walking alerts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AlertDistanceSetting(settings: settings),
          const Text(batteryWarning),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed:
                !route.canGuide ||
                    session.active ||
                    session.starting ||
                    session.stopping
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Start walking alerts?'),
                        content: SingleChildScrollView(
                          child: Text(
                            'Alert distance: ${settings.offRouteMetres.round()} metres.\n\n$batteryWarning\n\nGPS stays active when you lock the screen or leave this map. Use Stop walking alerts in the app to end the session.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Start walking'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    try {
                      await session.start(route, settings.offRouteMetres);
                    } catch (error) {
                      if (context.mounted) showFailure(context, error);
                    }
                  },
            icon: const Icon(Icons.hiking),
            label: Text(
              session.starting ? 'Starting…' : 'Start walking alerts',
            ),
          ),
          if (!route.canGuide)
            const Text('Alerts require a complete validated stage route.'),
          TextButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
            child: const Text('Open phone permissions'),
          ),
        ],
      ),
    );
  }
}

/// Kept outside the navigator so Stop is accessible from every app screen.
class WalkingSessionBanner extends StatelessWidget {
  const WalkingSessionBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final session = NavigationSession.instance;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.supported ||
            (!session.active && !session.starting && session.status.isEmpty)) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.active
                          ? '${session.stageName} · alert ${session.threshold.round()} m\n${session.status}'
                          : session.status,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await session.stop(message: '');
                    },
                    child: Text(
                      session.active || session.starting
                          ? 'Stop walking alerts'
                          : 'Dismiss',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
