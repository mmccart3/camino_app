import 'package:flutter/material.dart';

const appTitle = 'Saint Jean to Santiago';
const caminoYellow = Color(0xFFFFD740);
const caminoBlue = Color(0xFF1456A0);

/// Fiesta is bundled so branding is available without a network connection.
class AppTitle extends StatelessWidget {
  final bool compact;
  const AppTitle({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final text = Text(
      appTitle,
      textAlign: TextAlign.center,
      maxLines: compact ? 1 : null,
      style: TextStyle(
        fontFamily: 'Fiesta',
        fontSize: compact ? 28 : 44,
        height: 1.2,
        color: caminoYellow,
      ),
    );
    return compact ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;
  }
}
