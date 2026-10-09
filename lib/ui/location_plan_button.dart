import 'package:flutter/material.dart';
import '../data/camino_repository.dart';
import '../data/models.dart';
import '../services/camino_plan_store.dart';
import '../services/settings_service.dart';
import 'unestimated_day_screen.dart';
import 'widgets.dart';

class LocationPlanButton extends StatefulWidget {
  final CaminoRepository repository;
  final Location location;
  final int? initialStartId;
  const LocationPlanButton({
    super.key,
    required this.repository,
    required this.location,
    this.initialStartId,
  });
  @override
  State<LocationPlanButton> createState() => _LocationPlanButtonState();
}

class _LocationPlanButtonState extends State<LocationPlanButton> {
  bool busy = false;
  Future<void> add() async {
    setState(() => busy = true);
    final settings = SettingsService();
    try {
      final store = CaminoPlanStore.instance;
      final plans = await store.plans();
      if (!mounted) return;
      final selected = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose a plan'),
          children: [
            for (final plan in plans)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, plan.id),
                child: Text(plan.name),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Create a new plan'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      var planId = selected;
      if (selected == -1) {
        final name = await showDialog<String>(
          context: context,
          builder: (_) => const _NewPlanDialog(),
        );
        if (name == null) return;
        planId = await store.create(name);
      }
      final days = await store.days(planId);
      await settings.load();
      if (!mounted) return;
      final day = await Navigator.of(context).push<ItineraryDay>(
        MaterialPageRoute(
          builder: (_) => UnestimatedDayScreen(
            repository: widget.repository,
            planId: planId,
            pace: settings.paceKmh,
            previous: days.lastOrNull,
            initialDestinationId: widget.location.id,
            initialStartId: widget.initialStartId,
          ),
        ),
      );
      if (day == null) return;
      await store.saveDay(day);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day added to My Camino plan.')),
        );
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      settings.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : add,
    icon: const Icon(Icons.playlist_add),
    label: Text(busy ? 'Opening plan...' : 'Add to my plan'),
  );
}

class _NewPlanDialog extends StatefulWidget {
  const _NewPlanDialog();
  @override
  State<_NewPlanDialog> createState() => _NewPlanDialogState();
}

class _NewPlanDialogState extends State<_NewPlanDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New plan'),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Plan name'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Create'),
      ),
    ],
  );
}
