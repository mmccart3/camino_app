import 'package:flutter/material.dart';
import '../services/safe_links.dart';

void navigate(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
void showFailure(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(error.toString())));

class DataView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) builder;
  const DataView({super.key, required this.future, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Unable to load local data.\n${snapshot.error}',
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(snapshot.data as T);
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
