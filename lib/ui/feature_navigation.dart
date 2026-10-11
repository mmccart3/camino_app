import 'package:flutter/material.dart';

/// Lets existing contextual links switch tabs without creating duplicate screens.
class FeatureNavigation extends InheritedWidget {
  final bool Function(Widget screen) open;
  final int selected;
  const FeatureNavigation({
    super.key,
    required this.open,
    required this.selected,
    required super.child,
  });
  static bool handle(BuildContext context, Widget screen) =>
      context.getInheritedWidgetOfExactType<FeatureNavigation>()?.open(
        screen,
      ) ??
      false;
  @override
  bool updateShouldNotify(FeatureNavigation oldWidget) =>
      selected != oldWidget.selected;
}
