import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';

/// Displays detailed information and AI suggestions for a specific task.
class TaskDetailPage extends StatelessWidget {
  final Map<String, dynamic> task;
  const TaskDetailPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Mock instructions and AI suggestions
    final instructions =
        '1. Prepare equipment\n2. Follow safety guidelines\n3. Apply as directed';
    final aiSuggestion =
        'AI Suggestion: Apply in the early morning for best results. Avoid if rain is forecast.';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          task['title'] ?? 'Task Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: colorScheme.primary.withAlpha((0.85 * 255).toInt()),
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  instructions,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withAlpha(
                      (0.85 * 255).toInt(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'AI Recommendation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  aiSuggestion,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withAlpha(
                      (0.85 * 255).toInt(),
                    ),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
