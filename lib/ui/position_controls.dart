import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/navigation_session.dart';
import '../services/settings_service.dart';

/// Foreground refreshes only. Active walking alerts own their GPS schedule.
class PositionControls extends StatefulWidget {
  final List<Widget> additionalOptions;
  final SettingsService settings;
  final ValueChanged<Position> onPosition;
  final DateTime? initialTimestamp;
  final Future<Position> Function()? locate;
  const PositionControls({
    super.key,
    required this.settings,
    required this.onPosition,
    this.initialTimestamp,
    this.locate,
    this.additionalOptions = const [],
  });
  @override
  State<PositionControls> createState() => _PositionControlsState();
}

class _PositionControlsState extends State<PositionControls>
    with WidgetsBindingObserver {
  Timer? timer, statusTimer;
  bool visible = false, busy = false;
  int generation = 0;
  DateTime? updated;
  String? error;
  bool get foreground =>
      visible &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    updated = widget.initialTimestamp;
    statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && foreground && updated != null) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(schedule);
    NavigationSession.instance.addListener(sessionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowVisible = TickerMode.valuesOf(context).enabled;
    if (nowVisible != visible) {
      visible = nowVisible;
      schedule();
    }
  }

  void schedule() {
    generation++;
    timer?.cancel();
    if (foreground && widget.settings.autoPosition) {
      timer = Timer.periodic(
        Duration(seconds: widget.settings.positionIntervalSeconds),
        (_) => refresh(),
      );
      // Defer past the current build when returning to a map.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && foreground && widget.settings.autoPosition) refresh();
      });
    }
    if (mounted) setState(() {});
  }

  void sessionChanged() {
    final session = NavigationSession.instance;
    final fix = session.position;
    if (foreground &&
        session.active &&
        fix != null &&
        fix.timestamp != updated) {
      accept(fix);
    }
    if (mounted) setState(() {});
  }

  void accept(Position fix) {
    setState(() {
      updated = fix.timestamp;
      error = null;
    });
    widget.onPosition(fix);
  }

  Future<void> refresh() async {
    if (busy || !foreground) return;
    final session = NavigationSession.instance;
    if (session.active) {
      final fix = session.position;
      if (fix != null) accept(fix);
      return;
    }
    final token = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final fix = await (widget.locate ?? LocationService().current)();
      if (mounted && foreground && token == generation) accept(fix);
    } catch (_) {
      if (mounted && foreground && token == generation) {
        setState(
          () => error =
              'Position unavailable. Check location permission and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save this setting. Please retry.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => schedule();
  @override
  void dispose() {
    generation++;
    timer?.cancel();
    statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(schedule);
    NavigationSession.instance.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
          ),
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.my_location),
          label: Text(busy ? 'Finding position…' : 'Update my position'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            busy
                ? 'GPS: finding position…'
                : updated == null
                ? 'GPS: position not updated yet'
                : DateTime.now().difference(updated!).inSeconds > 120
                ? 'GPS: position is old (${DateTime.now().difference(updated!).inMinutes} min ago). Refresh before relying on guidance.'
                : 'GPS: updated recently',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (error != null) Text(error!),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Navigation options'),
          leading: const Icon(Icons.tune),
          subtitle: Text(
            settings.autoPosition
                ? 'Auto update: ${settings.positionIntervalSeconds < 60 ? "30 seconds" : "${settings.positionIntervalSeconds ~/ 60} min"}'
                : 'Automatic updates off',
          ),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic position updates'),
              value: settings.autoPosition,
              onChanged: (v) => save(settings.setAutoPosition(v)),
            ),
            DropdownButtonFormField<int>(
              key: ValueKey(settings.positionIntervalSeconds),
              initialValue: settings.positionIntervalSeconds,
              decoration: const InputDecoration(labelText: 'Update interval'),
              items: [
                for (final seconds in SettingsService.positionIntervals)
                  DropdownMenuItem(
                    value: seconds,
                    child: Text(
                      seconds == 30
                          ? '30 seconds'
                          : seconds == 60
                          ? '1 minute'
                          : '${seconds ~/ 60} minutes',
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) save(settings.setPositionInterval(v));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep map centred on me'),
              value: settings.followPosition,
              onChanged: (v) => save(settings.setFollowPosition(v)),
            ),
            Text(
              NavigationSession.instance.active
                  ? 'Using walking-alert GPS updates. Its update frequency is unchanged.'
                  : 'Automatic updates run while this map is visible. Shorter intervals use more battery.',
            ),
            ...widget.additionalOptions,
          ],
        ),
      ],
    );
  }
}
