import 'package:flutter/material.dart';

/// Reserve system navigation space for every route and the walking banner.
/// Scaffolds continue to handle the status bar and keyboard themselves.
class AppViewport extends StatelessWidget {
  final Widget child;
  const AppViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: child);
}
