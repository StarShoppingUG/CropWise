import 'package:flutter/material.dart';

LinearGradient appBackgroundGradient(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return LinearGradient(
    colors: [
      colorScheme.surface,
      colorScheme.primary.withAlpha((0.04 * 255).toInt()),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
