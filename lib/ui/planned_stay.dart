import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/camino_plan_store.dart';

Future<PlannedStay?> editPlannedStay(BuildContext context, PlannedStay stay) =>
    showDialog<PlannedStay>(
      context: context,
      builder: (_) => _StayDialog(stay),
    );

class _StayDialog extends StatefulWidget {
  final PlannedStay stay;
  const _StayDialog(this.stay);
  @override
  State<_StayDialog> createState() => _StayDialogState();
}

class _StayDialogState extends State<_StayDialog> {
  late String status = widget.stay.status;
  late final reference = TextEditingController(text: widget.stay.reference);
  late final notes = TextEditingController(text: widget.stay.notes);
  @override
  void dispose() {
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.stay.name),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Book through the accommodation links, then record your status here. Saving does not make a booking.',
          ),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Booking status'),
            items: [
              for (final value in PlannedStay.statuses)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (v) => setState(() => status = v!),
          ),
          TextField(
            controller: reference,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Booking reference (optional)',
            ),
          ),
          TextField(
            controller: notes,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          PlannedStay(
            id: widget.stay.id,
            kind: widget.stay.kind,
            name: widget.stay.name,
            status: status,
            reference: reference.text.trim(),
            notes: notes.text.trim(),
          ),
        ),
        child: const Text('Save stay'),
      ),
    ],
  );
}

/// Available on both accommodation detail pages, including visits from locations.
class AddStayToPlanButton extends StatefulWidget {
  final Accommodation place;
  final CaminoPlanStore? store;
  const AddStayToPlanButton({super.key, required this.place, this.store});
  @override
  State<AddStayToPlanButton> createState() => _AddStayToPlanButtonState();
}

class _AddStayToPlanButtonState extends State<AddStayToPlanButton> {
  bool busy = false;
  Future<void> add() async {
    setState(() => busy = true);
    try {
      final store = widget.store ?? CaminoPlanStore.instance;
      final choices = <(CaminoPlan, ItineraryDay)>[];
      for (final plan in await store.plans()) {
        for (final day in await store.days(plan.id)) {
          if (day.endId == widget.place.locationId) choices.add((plan, day));
        }
      }
      if (!mounted) return;
      if (choices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'First add a day ending here in My Camino plan on the home page.',
            ),
          ),
        );
        return;
      }
      final selected = await showDialog<ItineraryDay>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose the night for this stay'),
          children: [
            for (final entry in choices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, entry.$2),
                child: Text(
                  '${entry.$1.name} | ${entry.$2.route.date ?? "Undated day"}\n${entry.$2.startName} to ${entry.$2.endName}\n${entry.$2.stay == null ? "No stay selected" : "Replace: ${entry.$2.stay!.name}"}',
                ),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      final old = selected.stay;
      final candidate = PlannedStay.fromAccommodation(widget.place);
      final stay = await editPlannedStay(
        context,
        old?.id == candidate.id && old?.kind == candidate.kind
            ? old!
            : candidate,
      );
      if (stay == null) return;
      await store.setStay(
        selected.id,
        stay,
        locationId: widget.place.locationId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stay saved to your Camino plan.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the stay. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton.icon(
      onPressed: busy ? null : add,
      icon: const Icon(Icons.hotel_outlined),
      label: const Text('Add to my Camino plan'),
    ),
  );
}
