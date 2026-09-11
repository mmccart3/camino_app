import 'package:flutter/material.dart';
import '../services/safe_links.dart';
import 'widgets.dart';

/// Maps and charts retain their original proportions, unlike photo thumbnails.
class PublishedImage extends StatelessWidget {
  final String? url;
  final String title;
  final ImageProvider? imageProvider;
  const PublishedImage({
    super.key,
    required this.url,
    required this.title,
    this.imageProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (imageProvider == null && (url == null || !SafeLinks.isSafe(url!))) {
      return const _Unavailable();
    }
    final provider = imageProvider ?? NetworkImage(url!);
    void open() =>
        navigate(context, _FullScreenImage(provider: provider, title: title));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Open $title full screen',
          child: InkWell(
            onTap: open,
            child: Image(
              image: provider,
              width: double.infinity,
              fit: BoxFit.contain,
              semanticLabel: title,
              frameBuilder: (context, child, frame, synchronous) =>
                  frame == null && !synchronous
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : child,
              errorBuilder: (_, _, _) => const _Unavailable(),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: open,
          icon: const Icon(Icons.fullscreen),
          label: const Text('Open full screen · zoom and pan'),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 120,
    child: Center(
      child: Text('Image unavailable. Connect to the internet to load it.'),
    ),
  );
}

class _FullScreenImage extends StatefulWidget {
  final ImageProvider provider;
  final String title;
  const _FullScreenImage({required this.provider, required this.title});
  @override
  State<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<_FullScreenImage> {
  final controller = TransformationController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void zoom(double factor, Size size) {
    final current = controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 8.0);
    if (target == 1) {
      controller.value = Matrix4.identity();
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final point = controller.toScene(center);
    controller.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - point.dx * target,
        center.dy - point.dy * target,
        0,
        1,
      )
      ..scaleByDouble(target, target, 1, 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: controller,
                  minScale: 1,
                  maxScale: 8,
                  child: SizedBox.expand(
                    child: Image(
                      image: widget.provider,
                      fit: BoxFit.contain,
                      semanticLabel: widget.title,
                      errorBuilder: (_, _, _) => const _Unavailable(),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Card(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: () => zoom(1 / 1.5, size),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Reset zoom',
                        onPressed: () {
                          controller.value = Matrix4.identity();
                        },
                        icon: const Icon(Icons.fit_screen),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: () => zoom(1.5, size),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
