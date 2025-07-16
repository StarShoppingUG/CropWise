import 'package:flutter/material.dart';
import '../../services/plans_service.dart';
import '../widgets/app_gradients.dart';
import '../widgets/custom_app_bar.dart';
import '../pages/plan_detail_page.dart';
import 'plan_card.dart';

class PlansListWidget extends StatefulWidget {
  final String title;
  final bool showActiveOnly;
  final bool showCompletedOnly;

  const PlansListWidget({
    super.key,
    this.title = 'My Plans',
    this.showActiveOnly = false,
    this.showCompletedOnly = false,
  });

  @override
  State<PlansListWidget> createState() => _PlansListWidgetState();
}

class _PlansListWidgetState extends State<PlansListWidget> {
  final PlansService _plansService = PlansService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = appBackgroundGradient(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: widget.title,
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
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream:
                widget.showActiveOnly
                    ? _plansService.getActivePlans()
                    : widget.showCompletedOnly
                    ? _plansService.getCompletedPlans()
                    : _plansService.getUserPlans(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading plans',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(
                            (0.7 * 255).toInt(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final plans = snapshot.data ?? [];

              if (plans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.agriculture_outlined,
                        size: 64,
                        color: colorScheme.onSurface.withAlpha(
                          (0.5 * 255).toInt(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.showActiveOnly
                            ? 'No active plans'
                            : widget.showCompletedOnly
                            ? 'No completed plans'
                            : 'No plans yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.showActiveOnly
                            ? 'Create a new farming plan to get started'
                            : widget.showCompletedOnly
                            ? 'Complete some plans to see them here'
                            : 'Start by creating your first farming plan',
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(
                            (0.7 * 255).toInt(),
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: PlanCard(
                      plan: plan,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlanDetailPage(plan: plan),
                          ),
                        );
                      },
                      onDelete: () => _showDeleteDialog(plan),
                      onComplete:
                          plan['isCompleted'] == true
                              ? null
                              : () => _markAsCompleted(plan),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> plan) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Plan'),
            content: Text(
              'Are you sure you want to delete the "${plan['crop']} Farming Plan"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  navigator.pop(context);
                  try {
                    await _plansService.deletePlan(plan['id']);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Plan deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error deleting plan: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _markAsCompleted(Map<String, dynamic> plan) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark as Completed'),
            content: Text(
              'Mark the "${plan['crop']} Farming Plan" as completed?',
            ),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  navigator.pop(context);
                  try {
                    await _plansService.markPlanAsCompleted(plan['id']);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Plan marked as completed'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error updating plan: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Complete'),
              ),
            ],
          ),
    );
  }
}
