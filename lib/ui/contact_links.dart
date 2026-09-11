import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/safe_links.dart';
import '../services/map_links.dart';
import 'widgets.dart';

class ContactLinks extends StatelessWidget {
  final Accommodation place;
  final Future<void> Function(String) call, open, openWebsite, email;
  const ContactLinks({
    super.key,
    required this.place,
    this.call = SafeLinks.call,
    this.email = SafeLinks.email,
    this.open = SafeLinks.open,
    this.openWebsite = SafeLinks.openWebsite,
  });

  Future<void> _launch(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = SafeLinks.emailAddress(place.email);
    final website = place.websiteUrl;
    final hasWebsite = website != null && SafeLinks.isWebsite(website);
    final phones = place.phoneNumbers;
    final whatsApp = place.whatsAppNumber;
    final directions = MapLinks.walkingDirections(place.position);
    final appleDirections = Theme.of(context).platform == TargetPlatform.iOS
        ? MapLinks.appleWalkingDirections(place.position)
        : null;
    if (phones.isEmpty &&
        whatsApp == null &&
        directions == null &&
        !hasWebsite &&
        address == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Contact & directions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (address != null)
          TextButton.icon(
            onPressed: () => _launch(context, () => email(address)),
            icon: const Icon(Icons.email_outlined),
            label: Text('Email $address'),
          ),
        if (hasWebsite)
          TextButton.icon(
            onPressed: () => _launch(context, () => openWebsite(website)),
            icon: const Icon(Icons.language),
            label: const Text('Visit accommodation website'),
          ),
        if (directions != null)
          TextButton.icon(
            onPressed: () => _launch(context, () => open(directions)),
            icon: const Icon(Icons.directions_walk),
            label: const Text('Walk here with Google Maps'),
          ),
        if (appleDirections != null)
          TextButton.icon(
            onPressed: () => _launch(context, () => open(appleDirections)),
            icon: const Icon(Icons.directions_walk),
            label: const Text('Walk here with Apple Maps'),
          ),
        for (final phone in phones)
          TextButton.icon(
            onPressed: () => _launch(context, () => call(phone.international)),
            icon: const Icon(Icons.phone_outlined),
            label: Text('Call ${phone.international}'),
          ),
        if (whatsApp != null)
          TextButton.icon(
            onPressed: () => _launch(context, () => open(whatsApp.whatsAppUrl)),
            icon: const Icon(Icons.chat_outlined),
            label: Text('WhatsApp ${whatsApp.international}'),
          ),
      ],
    );
  }
}
