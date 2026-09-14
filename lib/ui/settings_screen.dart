import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'widgets.dart';
import 'splash_screen.dart';
import 'walking_alerts.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  const SettingsScreen({super.key, required this.settings});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double pace = widget.settings.paceKmh;
  bool saving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AppVersionLabel(),
        const SizedBox(height: 20),
        Text('Walking pace', style: Theme.of(context).textTheme.headlineSmall),
        Text(
          '${pace.toStringAsFixed(1)} km/h',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Slider(
          value: pace,
          min: SettingsService.minimumPaceKmh,
          max: SettingsService.maximumPaceKmh,
          divisions: 75,
          label: '${pace.toStringAsFixed(1)} km/h',
          onChanged: saving
              ? null
              : (value) => setState(() {
                  pace = value;
                }),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                  });
                  try {
                    await widget.settings.setPace(pace);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Walking pace saved on this device.'),
                        ),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showFailure(context, error);
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        saving = false;
                      });
                    }
                  }
                },
          child: Text(saving ? 'Saving…' : 'Save pace'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Time estimates use weighted distances and your saved average walking pace. Distances use the stored 3D metres. Estimates start at the nearest track point and exclude breaks and the walk back to it.',
        ),
        const SizedBox(height: 20),
        AlertDistanceSetting(settings: widget.settings),
        const Text(batteryWarning),
        const SizedBox(height: 20),
        const Text(
          'Location is requested when you update your position or explicitly start walking alerts. Stop walking alerts to end continuous GPS use.',
        ),
      ],
    ),
  );
}
