import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';
import '../widgets/custom_app_bar.dart';
import '../../services/plans_service.dart';
import 'plan_detail_page.dart';
import '../widgets/plan_card.dart';

/// Displays a list of the user's farming plans.
class PlansListPage extends StatefulWidget {
  const PlansListPage({super.key});

  @override
  State<PlansListPage> createState() => _PlansListPageState();
}

class _PlansListPageState extends State<PlansListPage> {
  final PlansService _plansService = PlansService();

  int _selectedFilter = 0; // 0: All, 1: Active, 2: Completed
  static const _filterLabels = ['All', 'Active', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundGradient = appBackgroundGradient(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'My Farming Plans',
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ToggleButtons(
                      isSelected: List.generate(3, (i) => i == _selectedFilter),
                      onPressed: (index) {
                        setState(() {
                          _selectedFilter = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      selectedColor: colorScheme.onPrimary,
                      fillColor: colorScheme.primary,
                      color: colorScheme.primary,
                      constraints: const BoxConstraints(
                        minWidth: 90,
                        minHeight: 36,
                      ),
                      children:
                          _filterLabels.map((label) => Text(label)).toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _plansService.getUserPlans(),
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
                    // Filter plans by status
                    final filteredPlans =
                        _selectedFilter == 0
                            ? plans
                            : plans
                                .where(
                                  (plan) =>
                                      _selectedFilter == 1
                                          ? plan['isCompleted'] != true
                                          : plan['isCompleted'] == true,
                                )
                                .toList();

                    if (filteredPlans.isEmpty) {
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
                              'No plans found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface.withAlpha(
                                  (0.7 * 255).toInt(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your farming plans will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withAlpha(
                                  (0.5 * 255).toInt(),
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        // The stream will automatically refresh
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredPlans.length,
                        itemBuilder: (context, index) {
                          final plan = filteredPlans[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: PlanCard(
                              plan: plan,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => PlanDetailPage(plan: plan),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> plan) {
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _plansService.deletePlan(plan['id']);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting plan: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _plansService.markPlanAsCompleted(plan['id']);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan marked as completed'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating plan: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Complete'),
              ),
            ],
          ),
    );
  }
}
