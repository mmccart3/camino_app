import 'package:flutter/material.dart';

/// A compact, wrapping summary that also works with large accessibility text.
class NavigationSummary extends StatelessWidget {
  final String title, distance, time;
  final String? remaining, warning, status;
  const NavigationSummary({
    super.key,
    required this.title,
    required this.distance,
    required this.time,
    this.remaining,
    this.warning,
    this.status,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              metric(context, Icons.route, distance, 'Distance'),
              metric(context, Icons.schedule, time, 'Walking time'),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 12),
            Text(remaining!),
          ],
          if (warning != null || status != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warning != null
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    warning != null
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 28,
                    color: warning != null
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warning ?? status!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: warning != null
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  Widget metric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 24),
      const SizedBox(width: 8),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    ],
  );
}

String navigationTime(Duration? duration) {
  if (duration == null) return 'Unavailable';
  final minutes = (duration.inSeconds / 60).ceil();
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} hr ${minutes % 60} min';
}

double navigationMapHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.60).clamp(280.0, 620.0);
