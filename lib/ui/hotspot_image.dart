import 'package:flutter/material.dart';
import '../data/models.dart' show MapHotspot, Location;

/// Image and hit targets share the same layout and InteractiveViewer transform.
class HotspotImage extends StatefulWidget {
  final ImageProvider provider;
  final String title;
  final List<MapHotspot> hotspots;
  final ValueChanged<Location>? onLocationTap;
  final bool expand;
  const HotspotImage({
    super.key,
    required this.provider,
    required this.title,
    required this.hotspots,
    this.onLocationTap,
    this.expand = false,
  });

  @override
  State<HotspotImage> createState() => _HotspotImageState();
}

class _HotspotImageState extends State<HotspotImage> {
  ImageStream? stream;
  late final listener = ImageStreamListener(receive, onError: failed);
  Size? pixels;

  void receive(ImageInfo info, bool synchronous) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (mounted) setState(() => pixels = size);
  }

  void failed(Object error, StackTrace? stack) {
    if (mounted) setState(() => pixels = null);
  }

  void resolve() {
    final next = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (next.key == stream?.key) return;
    stream?.removeListener(listener);
    pixels = null;
    stream = next..addListener(listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    resolve();
  }

  @override
  void didUpdateWidget(HotspotImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    resolve();
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: widget.expand ? StackFit.expand : StackFit.loose,
    children: [
      Image(
        image: widget.provider,
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: widget.title,
        frameBuilder: (context, child, frame, synchronous) =>
            frame == null && !synchronous
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : child,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 120,
          child: Center(child: Text('Image unavailable in this app version.')),
        ),
      ),
      if (pixels != null && widget.onLocationTap != null)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final fitted = applyBoxFit(BoxFit.contain, pixels!, size);
              final imageRect = Alignment.center.inscribe(
                fitted.destination,
                Offset.zero & size,
              );
              final scale = imageRect.width / pixels!.width;
              return Stack(
                children: [
                  for (final hotspot in widget.hotspots)
                    if (hotspot.isValid &&
                        hotspot.left < pixels!.width &&
                        hotspot.top < pixels!.height)
                      Positioned(
                        left: imageRect.left + hotspot.left * scale,
                        top: imageRect.top + hotspot.top * scale,
                        width:
                            (hotspot.right.clamp(0, pixels!.width) -
                                hotspot.left) *
                            scale,
                        height:
                            (hotspot.bottom.clamp(0, pixels!.height) -
                                hotspot.top) *
                            scale,
                        child: Tooltip(
                          message: 'Open ${hotspot.location.name}',
                          child: Semantics(
                            link: true,
                            label: 'Open ${hotspot.location.name}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey('map-hotspot-${hotspot.id}'),
                                onTap: () =>
                                    widget.onLocationTap!(hotspot.location),
                                mouseCursor: SystemMouseCursors.click,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
    ],
  );
}
