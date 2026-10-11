import 'package:flutter/material.dart';

/// Horizontal page gestures compete normally with embedded map/chart gestures.
/// Interactive children claim their own drags; the labelled controls always work.
class DetailPager<T> extends StatefulWidget {
  final List<T> items;
  final ValueChanged<T>? onChanged;
  final int initialIndex;
  final String Function(T) label;
  final Widget Function(T) builder;
  const DetailPager({
    super.key,
    required this.items,
    this.onChanged,
    required this.initialIndex,
    required this.label,
    required this.builder,
  });
  @override
  State<DetailPager<T>> createState() => _DetailPagerState<T>();
}

class _DetailPagerState<T> extends State<DetailPager<T>> {
  late int index = widget.initialIndex;
  late final controller = PageController(initialPage: index);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(int offset) => controller.animateToPage(
    index + offset,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
  );
  @override
  Widget build(BuildContext context) {
    if (widget.items.length < 2) return widget.builder(widget.items.single);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: widget.items.length,
            onPageChanged: (value) {
              setState(() => index = value);
              widget.onChanged?.call(widget.items[value]);
            },
            itemBuilder: (context, i) =>
                _RetainedPage(child: widget.builder(widget.items[i])),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: index > 0 ? () => move(-1) : null,
                      child: Text(
                        index > 0
                            ? '‹ Previous\n${widget.label(widget.items[index - 1])}'
                            : 'Start of list',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Text(
                    '${index + 1}/${widget.items.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: index + 1 < widget.items.length
                          ? () => move(1)
                          : null,
                      child: Text(
                        index + 1 < widget.items.length
                            ? 'Next ›\n${widget.label(widget.items[index + 1])}'
                            : 'End of list',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RetainedPage extends StatefulWidget {
  final Widget child;
  const _RetainedPage({required this.child});
  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
