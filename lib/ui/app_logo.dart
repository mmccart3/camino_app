import 'package:flutter/material.dart';

/// The same borderless artwork used by the installed app icon.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) => Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/branding/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Saint Jean to Santiago logo',
      ),
    ),
  );
}
