import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'widgets.dart';
import 'splash_screen.dart';
import 'walking_alerts.dart';
import 'app_title.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  const SettingsScreen({super.key, required this.settings});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double pace = widget.settings.paceKmh;
  bool saving = false;
  late final double minimum = pace < 2 ? pace : 2;
  late final double maximum = pace > 7 ? pace : 7;
  Future<void> save(double value) async {
    setState(() => saving = true);
    try {
      await widget.settings.setPace(double.parse(value.toStringAsFixed(1)));
      if (mounted) showSettingsSaved(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget section(String label, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: caminoYellow),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Walking speed', [
            Text(
              '${pace.toStringAsFixed(1)} km/h',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SliderTheme(
              data: settingsSliderTheme(context),
              child: Slider(
                value: pace,
                // Keep previously saved speeds outside the new suggested range editable.
                min: minimum,
                max: maximum,
                label: '${pace.toStringAsFixed(1)} km/h',
                onChanged: saving
                    ? null
                    : (value) => setState(() => pace = value),
                onChangeEnd: saving ? null : save,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Relaxed ${minimum.toStringAsFixed(1)}'),
                Text('Brisk ${maximum.toStringAsFixed(1)}'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Times use your flat-ground speed and adjust for climbs and descents. Breaks are not included.',
            ),
          ]),
          section('Off-route alerts', [
            AlertDistanceSetting(settings: widget.settings),
            const Text(
              'Continuous GPS can drain the battery. Start with enough charge and stop the session when you finish.',
            ),
            const SizedBox(height: 8),
            const Text('Force-closing the app stops tracking.'),
            const ExpansionTile(
              title: Text('Location and privacy'),
              tilePadding: EdgeInsets.zero,
              children: [
                Text(batteryWarning),
                Text(
                  'Location is requested when you update your position or explicitly start walking alerts. Stop walking alerts to end continuous GPS use.',
                ),
              ],
            ),
          ]),
          section('About', [
            const AppVersionLabel(),
            const SizedBox(height: 8),
            const Text('Map data (c) OpenStreetMap contributors'),
            const Text('OpenMapTiles'),
          ]),
        ],
      ),
    ),
  );
}
