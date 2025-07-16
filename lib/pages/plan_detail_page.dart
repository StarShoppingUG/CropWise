import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_app_bar.dart';

// Displays detailed information about a user's farming plan.
class PlanDetailPage extends StatefulWidget {
  final Map<String, dynamic> plan;

  const PlanDetailPage({super.key, required this.plan});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  List<String> _generalRecommendations = [];

  @override
  void initState() {
    super.initState();
    _loadStoredRecommendations();
  }

  void _loadStoredRecommendations() {
    // Use the recommendations that were generated with the plan
    final storedRecommendations =
        widget.plan['recommendations'] as List<dynamic>? ?? [];
    setState(() {
      _generalRecommendations =
          storedRecommendations.map((rec) => rec.toString()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundGradient = appBackgroundGradient(context);

    final dailyTasks = widget.plan['daily_plan'] as List<dynamic>? ?? [];

    // Determine the starting day number for this plan
    int startDay = 1;
    if (widget.plan['parentPlanId'] != null &&
        widget.plan['startDay'] != null) {
      startDay = widget.plan['startDay'] as int;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Plan Details',
        backgroundColor: colorScheme.primary.withAlpha((0.85 * 255).toInt()),
        foregroundColor: colorScheme.onPrimary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Header
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(20),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                      colorScheme.surface.withAlpha((0.05 * 255).toInt()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: colorScheme.primary.withAlpha(
                    (0.2 * 255).toInt(),
                  ),
                  borderWidth: 1.5,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.06 * 255).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                              color: colorScheme.primary.withAlpha(
                                (0.1 * 255).toInt(),
                              ),
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
                                  '${widget.plan['crop']} Farming Plan',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.plan['location'] ?? 'Unknown Location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withAlpha(
                                      (0.7 * 255).toInt(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _PlanInfoCard(
                            title: 'Goal',
                            value: widget.plan['goal'] ?? 'Not specified',
                            icon: Icons.flag,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 12),
                          _PlanInfoCard(
                            title: 'Duration',
                            value:
                                '${widget.plan['duration'] ?? 'Variable'} Days',
                            icon: Icons.calendar_today,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // General Recommendations
                Text(
                  'General Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                      colorScheme.surface.withAlpha((0.05 * 255).toInt()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: colorScheme.primary.withAlpha(
                    (0.2 * 255).toInt(),
                  ),
                  borderWidth: 1.5,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.06 * 255).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_generalRecommendations.isEmpty)
                        Text(
                          'No general recommendations available for this plan.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withAlpha(
                              (0.7 * 255).toInt(),
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        ..._generalRecommendations.map(
                          (rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.tips_and_updates,
                                  size: 16,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rec,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Daily Tasks
                Text(
                  '${widget.plan['duration'] != null && widget.plan['duration'] > 0 ? '${widget.plan['duration']}-Day' : 'Complete'} Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...dailyTasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dayTask = entry.value as Map<String, dynamic>;

                  int displayDay = startDay + index;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withAlpha(
                                    (0.1 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Day $displayDay',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  dayTask['title'] ?? 'Daily Tasks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (dayTask['tasks'] != null) ...[
                            ...(dayTask['tasks'] as List<dynamic>).map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        task.toString(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (dayTask['notes'] != null &&
                              dayTask['notes'].isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.secondary.withAlpha(
                                  (0.1 * 255).toInt(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 16,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dayTask['notes'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface,
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final ColorScheme colorScheme;

  const _PlanInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha((0.1 * 255).toInt()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
