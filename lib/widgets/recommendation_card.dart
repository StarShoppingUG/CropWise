import 'package:flutter/material.dart';

class RecommendationCard extends StatelessWidget {
  final String headline;
  final List<String> actions;
  final String? tip;
  final IconData? icon;
  final Color? color;

  const RecommendationCard({
    super.key,
    required this.headline,
    required this.actions,
    this.tip,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.surfaceContainerHighest;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor.withAlpha((0.95 * 255).toInt()),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        a,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(
                            (0.85 * 255).toInt(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tip != null) ...[
              const SizedBox(height: 10),
              Text(
                '💡 $tip',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
