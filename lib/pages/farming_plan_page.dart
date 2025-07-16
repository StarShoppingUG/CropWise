import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../widgets/map_picker.dart';
import '../../services/user_service.dart';
import '../../services/plans_service.dart';
import '../../services/weather_service.dart';
import '../../services/ai_service.dart';
import '../../constants/crop_constants.dart';
import 'package:provider/provider.dart';
import '../models/location_provider.dart';

/// Shows the AI Smart Farming Plan Page allowing user to generate a personalized 14-day plan.
class FarmingPlanPage extends StatefulWidget {
  const FarmingPlanPage({super.key});

  @override
  State<FarmingPlanPage> createState() => _FarmingPlanPageState();
}

class _FarmingPlanPageState extends State<FarmingPlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final PlansService _plansService = PlansService();
  final UserService _userService = UserService();
  final WeatherService _weatherService = WeatherService();
  final AIService _aiService = AIService();
  final planSummaryKey = GlobalKey();

  String _selectedCrop = CropConstants.crops[0];
  String _selectedGoal = CropConstants.goals[0];
  int _credits = 0;
  bool _isLoading = false;
  String? _lastLocation;
  bool _planLimitReached = false; //Track if plan limit is reached

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkPlanLimit(); //Check plan limit on init
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = Provider.of<LocationProvider>(context).location;
    if (location.isNotEmpty && location != _lastLocation) {
      _lastLocation = location;
      _locationController.text = location;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (doc.exists) {
          setState(() {
            _credits = doc.data()?['credits'] ?? 0;
            _locationController.text = doc.data()?['location'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _showMapPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MapPicker(
              initialLocation: null,
              onLocationSelected: (location, lat, lng) {
                setState(() {
                  _locationController.text = location;
                });
              },
            ),
      ),
    );
  }

  Future<void> _generatePlan() async {
    if (_isLoading) return; // Prevent multiple concurrent calls
    setState(() => _isLoading = true);
    if (!_formKey.currentState!.validate() || _planLimitReached) {
      setState(() => _isLoading = false);
      return;
    }

    // Check premium status
    final isPremium = await _userService.isPremium();

    try {
      final plan = await _generateAIPlan();
      if (!mounted) return;

      // Validate plan before saving
      if (plan['daily_plan'] == null || (plan['daily_plan'] as List).isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate a valid plan. Please check your internet connection and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Save plan to Firestore first
      bool saveSuccess = false;
      try {
        await _savePlanToFirestore(plan);
        saveSuccess = true;
      } catch (e) {
        saveSuccess = false;
      }
      if (!saveSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save plan. Please check your internet connection and try again.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // If not premium, increment daily plan limit and deduct credit only after successful save
      if (!isPremium) {
        final allowed = await _userService.checkAndIncrementDailyPlanLimit(
          planLimit: 1,
        );
        if (!allowed) {
          setState(() {
            _planLimitReached = true;
          });
          return;
        }
        await _deductCredit();
        if (!mounted) return;
      }

      // Show non-dismissible dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Plan Created!',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crop:  ${plan['crop']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Location:  ${plan['location']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Goal:  ${plan['goal']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/plan_detail',
                          arguments: plan,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('View'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating plan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    _checkPlanLimit(); //Re-check plan limit after generation
  }

  Future<void> _deductCredit() async {
    try {
      final newCredits = _credits - 1;
      await _userService.updateUserCredits(newCredits);

      setState(() {
        _credits = newCredits;
      });
    } catch (e) {
      debugPrint('Error deducting credit: $e');
    }
  }

  Future<Map<String, dynamic>> _generateAIPlan() async {
    try {
      final location = _locationController.text;
      final weatherData = await _weatherService.getDailyForecast(
        location,
        days: 14,
      );
      final recommendations = await _aiService.generateFarmingRecommendations(
        crop: _selectedCrop,
        goal: _selectedGoal,
        weatherData: weatherData ?? [],
        location: location,
      );
      final dailyPlan = await _aiService.generateDailyPlan(
        crop: _selectedCrop,
        goal: _selectedGoal,
        weatherData: weatherData ?? [],
        location: location,
      );
      // Get duration from the actual plan generated by AI
      int duration = dailyPlan.isNotEmpty ? dailyPlan.length : 0;
      return {
        'crop': _selectedCrop,
        'location': location,
        'goal': _selectedGoal,
        'duration': duration,
        'recommendations': recommendations,
        'daily_plan': dailyPlan,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // print('Error generating AI plan: $e');
      return {
        'crop': _selectedCrop,
        'location': _locationController.text,
        'goal': _selectedGoal,
        'duration': 0, // No duration if plan generation fails
        'recommendations': [],
        'daily_plan': [],
        'generated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> _savePlanToFirestore(Map<String, dynamic> plan) async {
    try {
      await _plansService.savePlan(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan generated and saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      // Show error to user and log for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save plan: \n\n$e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Error saving plan to Firestore: $e\n$stack');
    }
  }

  Future<void> _checkPlanLimit() async {
    final isPremium = await _userService.isPremium();
    if (isPremium) {
      setState(() => _planLimitReached = false);
      return;
    }
    final reached = await _userService.isDailyPlanLimitReached(planLimit: 1);
    setState(() {
      _planLimitReached = reached;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = appBackgroundGradient(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTextColor = isLight ? Colors.white : Colors.black87;
    final buttonTextColor = isLight ? Colors.white : Colors.black;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userService.userStream(),
      builder: (context, snapshot) {
        final isPremium =
            snapshot.data?.data()?['membershipStatus'] == 'premium';
        // Always re-check the limit when membership changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkPlanLimit();
        });
        if (isPremium && _planLimitReached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _planLimitReached = false);
          });
        }
        return Stack(
          children: [
            Scaffold(
              body: Container(
                decoration: BoxDecoration(gradient: backgroundGradient),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 24.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 0),
                              GlassCard(
                                borderRadius: 28,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 18,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (0.08 * 255).toInt(),
                                    ),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: cardTextColor.withAlpha(
                                          (0.18 * 255).toInt(),
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.transparent,
                                        child: Icon(
                                          Icons.psychology,
                                          color: cardTextColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Smart Farming Plan',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: cardTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Generate your personalized \n14-day farming plan',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: cardTextColor.withAlpha(
                                                (0.9 * 255).toInt(),
                                              ),
                                            ),
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              GlassCard(
                                borderRadius: 24,
                                padding: const EdgeInsets.all(24),
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withAlpha(
                                      (0.15 * 255).toInt(),
                                    ),
                                    colorScheme.surface.withAlpha(
                                      (0.05 * 255).toInt(),
                                    ),
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
                                    color: Colors.black.withAlpha(
                                      (0.06 * 255).toInt(),
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Plan Details',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface
                                                  .withAlpha(
                                                    (0.6 * 255).toInt(),
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              isPremium
                                                  ? 'Unlimited'
                                                  : '1 plan per day',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      // Crop Selection
                                      Text(
                                        'Crop Type',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _selectedCrop,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme.surface
                                              .withAlpha((0.1 * 255).toInt()),
                                        ),
                                        items:
                                            CropConstants.crops
                                                .map(
                                                  (crop) => DropdownMenuItem(
                                                    value: crop,
                                                    child: Text(crop),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedCrop = value!;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Goal Selection
                                      Text(
                                        'Farming Goal',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _selectedGoal,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme.surface
                                              .withAlpha((0.1 * 255).toInt()),
                                        ),
                                        items:
                                            CropConstants.goals
                                                .map(
                                                  (goal) => DropdownMenuItem(
                                                    value: goal,
                                                    child: Text(goal),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedGoal = value!;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Location
                                      Text(
                                        'Farm Location',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 0,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: colorScheme.outline
                                                      .withAlpha(
                                                        (0.3 * 255).toInt(),
                                                      ),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: colorScheme.surface
                                                    .withAlpha(
                                                      (0.1 * 255).toInt(),
                                                    ),
                                              ),
                                              child: Text(
                                                _locationController.text.isEmpty
                                                    ? 'No location selected'
                                                    : _locationController.text,
                                                style: TextStyle(
                                                  color:
                                                      _locationController
                                                              .text
                                                              .isEmpty
                                                          ? colorScheme
                                                              .onSurface
                                                              .withAlpha(
                                                                (0.5 * 255)
                                                                    .toInt(),
                                                              )
                                                          : colorScheme
                                                              .onSurface,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              Icons.map,
                                              color: buttonTextColor,
                                            ),
                                            label: Text(
                                              'Pick',
                                              style: TextStyle(
                                                color: buttonTextColor,
                                              ),
                                            ),
                                            onPressed: _showMapPicker,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  colorScheme.secondary,
                                              foregroundColor: buttonTextColor,
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child:
                                            _planLimitReached && !isPremium
                                                ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      icon: Icon(
                                                        Icons.lock,
                                                        color:
                                                            colorScheme.primary,
                                                        size: 28,
                                                      ),
                                                      label: Text(
                                                        'Daily plan limit reached',
                                                        style: TextStyle(
                                                          color:
                                                              colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      onPressed: null,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            colorScheme.primary,
                                                        foregroundColor:
                                                            colorScheme
                                                                .onSurface,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        elevation: 4,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 16,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.upgrade,
                                                      ),
                                                      label: const Text(
                                                        'Upgrade to Premium',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            colorScheme.primary,
                                                        foregroundColor:
                                                            colorScheme
                                                                .onPrimary,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                        ),
                                                        elevation: 2,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pushNamed(
                                                          '/premium_upgrade_page',
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                )
                                                : ElevatedButton(
                                                  onPressed:
                                                      _isLoading
                                                          ? null
                                                          : _generatePlan,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        colorScheme.primary,
                                                    foregroundColor:
                                                        buttonTextColor,
                                                    textStyle: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    elevation: 4,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    shadowColor: colorScheme
                                                        .primary
                                                        .withAlpha(
                                                          (0.3 * 255).toInt(),
                                                        ),
                                                  ),
                                                  child:
                                                      _isLoading
                                                          ? SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  buttonTextColor,
                                                            ),
                                                          )
                                                          : Text(
                                                            'Generate Plan',
                                                            style: TextStyle(
                                                              color:
                                                                  buttonTextColor,
                                                            ),
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
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha((0.45 * 255).toInt()),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'Generating your personalized farming plan...\n\nThis may take a few moments as we analyze weather, crop, goal and location data.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
