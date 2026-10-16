import 'dart:async';
import 'package:flutter/services.dart';
import 'feature_navigation.dart';
import 'package:flutter/material.dart';
import '../services/safe_links.dart';

void navigate(BuildContext context, Widget screen) {
  if (FeatureNavigation.handle(context, screen)) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is TimeoutException) {
    return 'This is taking longer than expected. Please try again.';
  }
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('permission')) {
      return 'Permission is needed for this action. Check your device settings and try again.';
    }
    if (code.contains('location') || code.contains('gps')) {
      return 'Your position is unavailable. Check location services and try again.';
    }
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('database_closed')) {
    return 'The local guide is temporarily unavailable. Retry loading it.';
  }
  if (detail.contains('databaseexception') || detail.contains('sqlite')) {
    return 'The saved data could not be accessed. Please try again.';
  }
  if (detail.contains('socketexception')) {
    return 'The connection could not be made. Check your internet connection and try again.';
  }
  if (detail.contains('calling app')) {
    return 'A phone app could not be opened. You can dial the displayed number manually.';
  }
  if (detail.contains('website') || detail.contains('link')) {
    return 'This link could not be opened. Check the address or try again.';
  }
  return fallback;
}

Future<void> showFailure(
  BuildContext context,
  Object error, {
  Future<void> Function()? onRetry,
}) async {
  final retry = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unable to complete action'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(friendlyError(error)),
            ExpansionTile(
              title: const Text('Details'),
              children: [SelectableText(error.toString())],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        if (onRetry != null)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
      ],
    ),
  );
  if (retry == true && onRetry != null && context.mounted) {
    try {
      await onRetry();
    } catch (nextError) {
      if (context.mounted) {
        await showFailure(context, nextError, onRetry: onRetry);
      }
    }
  }
}

class DataView<T> extends StatefulWidget {
  final Future<T> future;
  final Future<T> Function() retry;
  final Widget Function(T) builder;
  const DataView({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
  });
  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  late Future<T> active = widget.future;
  @override
  void didUpdateWidget(covariant DataView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) active = widget.future;
  }

  void retry() {
    final next = Future<T>.sync(widget.retry);
    setState(() {
      active = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: active,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 40),
                const SizedBox(height: 12),
                Text(
                  friendlyError(
                    snapshot.error!,
                    fallback:
                        'The local guide could not be loaded. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                ExpansionTile(
                  title: const Text('Details'),
                  children: [SelectableText(snapshot.error.toString())],
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: Text('No data available.'));
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

class DatabaseImage extends StatelessWidget {
  final String? url;
  const DatabaseImage(this.url, {super.key});
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      height: 140,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.landscape_outlined, size: 36),
          Text('Image unavailable offline'),
        ],
      ),
    );
    if (url == null || !SafeLinks.isSafe(url!)) {
      return fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url!,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => fallback(),
      ),
    );
  }
}
