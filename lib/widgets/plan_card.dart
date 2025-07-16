import 'package:flutter/material.dart';
import 'glass_card.dart';
import '../services/ai_service.dart';
import '../services/weather_service.dart';
import '../services/plans_service.dart';
import '../pages/plan_detail_page.dart';
import '../services/user_service.dart';

class PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;
  final bool showPopupMenu;

  const PlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
    this.onComplete,
    this.showPopupMenu = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = plan['isCompleted'] == true;
    final createdAt = plan['createdAt'];
    final completedAt = plan['completedAt'];

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      borderColor: colorScheme.primary.withAlpha((0.35 * 255).toInt()),
      borderWidth: 1.2,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((0.10 * 255).toInt()),
          blurRadius: 18,
          spreadRadius: 2,
          offset: Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.agriculture,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan['crop']} Farming Plan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['location'] ?? 'Unknown Location',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withAlpha(170),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.schedule,
                          size: 16,
                          color:
                              isCompleted ? Colors.green : colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted ? 'Completed' : 'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isCompleted
                                    ? Colors.green
                                    : colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (plan['parentPlanId'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary.withAlpha(
                                (0.18 * 255).toInt(),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.loop,
                                  size: 14,
                                  color: colorScheme.tertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Continuation',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.tertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (showPopupMenu)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        onTap();
                        break;
                      case 'complete':
                        onComplete?.call();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'continue':
                        _showContinuePlanDialog(context);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        if (!isCompleted)
                          const PopupMenuItem(
                            value: 'complete',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle),
                                SizedBox(width: 8),
                                Text('Mark Complete'),
                              ],
                            ),
                          ),
                        if (!isCompleted)
                          const PopupMenuItem(
                            value: 'continue',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_add),
                                SizedBox(width: 8),
                                Text('Continue Plan'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurface.withAlpha(170),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PlanInfoChip(
                icon: Icons.flag,
                label: plan['goal'] ?? 'Not specified',
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              PlanInfoChip(
                icon: Icons.calendar_today,
                label:
                    createdAt != null ? _formatDate(createdAt) : 'Unknown date',
                colorScheme: colorScheme,
              ),
            ],
          ),
          if (isCompleted && completedAt != null) ...[
            const SizedBox(height: 8),
            PlanInfoChip(
              icon: Icons.check_circle,
              label: 'Completed: ${_formatDate(completedAt)}',
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    // Accepts DateTime or Timestamp (from Firestore)
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (date != null && date.toString().contains('Timestamp')) {
      // Firestore Timestamp
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return 'Unknown date';
  }

  void _showContinuePlanDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Continue Plan'),
            content: Text('Generate the next 14 days for this plan?'),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => navigator.pop(true),
                child: Text('Continue'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      final userService = UserService();
      final isPremium = await userService.isPremium();
      if (!isPremium) {
        final credits = await userService.getUserCredits();
        if (credits <= 0) {
          final upgrade = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Upgrade to Premium'),
                  content: Text(
                    'Basic members need credits to generate plans. Upgrade to premium for unlimited plans!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => navigator.pop(false),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => navigator.pop(true),
                      child: Text('Upgrade'),
                    ),
                  ],
                ),
          );
          if (upgrade == true) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Redirect to premium upgrade...'),
                backgroundColor: Colors.blue,
              ),
            );
            return;
          } else {
            return;
          }
        } else {
          await userService.updateUserCredits(credits - 1);
        }
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Generating continuation plan...\nPlease wait.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
      try {
        final aiService = AIService();
        final crop = plan['crop'] ?? '';
        final goal = plan['goal'] ?? '';
        final location = plan['location'] ?? '';
        final plansService = PlansService();
        final previousActivities = await getFullPreviousActivities(
          plansService,
          plan,
        );
        final weatherService = WeatherService();
        final weatherData = await weatherService.getDailyForecast(
          location,
          days: 14,
        );
        final lastDay = previousActivities.length;
        final continuationPlan = await aiService.generateContinuationPlan(
          crop: crop,
          goal: goal,
          location: location,
          lastDay: lastDay,
          previousActivities: previousActivities,
          weatherData: weatherData ?? [],
        );
        List flattenTasks(List tasks) {
          return tasks
              .expand((t) => t is List ? flattenTasks(t) : [t])
              .toList();
        }

        List<Map<String, dynamic>> flatDailyPlan =
            continuationPlan.map((day) {
              final tasks = day['tasks'];
              if (tasks is List) {
                final flatTasks = flattenTasks(tasks);
                return {...day, 'tasks': flatTasks};
              }
              return day;
            }).toList();
        final newPlan = {
          'crop': crop,
          'location': location,
          'goal': goal,
          'duration': flatDailyPlan.length,
          'recommendations': plan['recommendations'],
          'daily_plan': flatDailyPlan,
          'weatherAdvice': [],
          'generated_at': DateTime.now().toIso8601String(),
          'parentPlanId': plan['id'],
          'startDay': previousActivities.length + 1,
          'isCompleted': false,
        };
        final newPlanId = await plansService.savePlan(newPlan);
        Map<String, dynamic>? firestorePlan;
        try {
          firestorePlan = await plansService.getPlanById(newPlanId);
        } catch (e) {
          firestorePlan = null;
        }
        navigator.pop(); // Close loading dialog
        if (firestorePlan != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => PlanDetailPage(plan: firestorePlan!),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Plan saved, but failed to load from Firestore.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error continuing plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getFullPreviousActivities(
    PlansService plansService,
    Map<String, dynamic> plan,
  ) async {
    List<Map<String, dynamic>> allActivities = [];
    Map<String, dynamic>? currentPlan = plan;
    // Traverse back to the original plan
    while (currentPlan != null) {
      final dailyPlan =
          (currentPlan['daily_plan'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      allActivities.insertAll(0, dailyPlan); // prepend to keep order
      final parentId = currentPlan['parentPlanId'];
      if (parentId != null) {
        currentPlan = await plansService.getPlanById(parentId);
      } else {
        currentPlan = null;
      }
    }
    return allActivities;
  }
}

class PlanInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const PlanInfoChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
