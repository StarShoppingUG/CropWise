import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../../services/user_service.dart';
import '../../services/plans_service.dart';
import '../../services/weather_service.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../utils/weather_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/location_provider.dart';

// Dashboard page showing farm overview, Quick Actions, and recent plans.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userName = 'Farmer';
  bool isPremium = false;
  String? userLocation;
  String? _lastLocation;
  Map<String, dynamic>? currentHourWeather;
  bool _loadingWeather = true;
  final UserService _userService = UserService();
  final PlansService _plansService = PlansService();
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = Provider.of<LocationProvider>(context).location;
    if (location.isNotEmpty && location != _lastLocation) {
      _lastLocation = location;
      userLocation = location;
      _loadWeather();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null && userProfile['name'] != null) {
        final fullName = userProfile['name'] as String;
        final firstName = fullName.split(' ').first;
        final memberShipStatus = userProfile['membershipStatus'] ?? 'basic';
        setState(() {
          userName = firstName;
          isPremium = memberShipStatus == 'premium';
          userLocation = userProfile['location'];
        });
        _loadWeather();
      }
    } catch (e) {
      _showError('Error loading user data');
      setState(() => _loadingWeather = false);
    }
  }

  Future<void> _loadWeather() async {
    setState(() => _loadingWeather = true);
    try {
      if (userLocation == null) {
        setState(() => _loadingWeather = false);
        return;
      }
      final hourlyForecastRaw = await _weatherService.getHourlyForecastForUser(
        hours: 24,
        location: userLocation,
      );
      final hourlyForecast =
          (hourlyForecastRaw ?? []).cast<Map<String, dynamic>>();
      Map<String, dynamic> currentHourData;
      final now = DateTime.now();
      final nowHourStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:00';
      currentHourData = hourlyForecast.firstWhere(
        (h) => h['time'] == nowHourStr,
      );
      setState(() {
        currentHourWeather = currentHourData;
        _loadingWeather = false;
      });
    } catch (e) {
      _showError('Error loading weather');
      setState(() => _loadingWeather = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting
              Text(
                '${_getTimeBasedGreeting()},',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: _userService.userStream(),
                builder: (context, snapshot) {
                  String displayName = userName;
                  bool premium = isPremium;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      final fullName = data['name'] as String?;
                      if (fullName != null) {
                        displayName = fullName.split(' ').first;
                      }
                      premium =
                          (data['membershipStatus'] ?? 'basic') == 'premium';
                    }
                  }
                  return Row(
                    children: [
                      Text(
                        '$displayName!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: 1,
                        ),
                      ),
                      if (premium)
                        Icon(Icons.star, color: Colors.amber, size: 50)
                      else
                        Icon(Icons.lock, color: colorScheme.primary, size: 40),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your farm overview for today',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                ),
              ),
              const SizedBox(height: 32),

              // Weather & Advisory Card
              _loadingWeather
                  ? const Center(child: CircularProgressIndicator())
                  : (currentHourWeather == null
                      ? GlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 24,
                        ),
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderColor: Colors.white.withAlpha(
                          (0.2 * 255).toInt(),
                        ),
                        borderWidth: 1,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.1 * 255).toInt()),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        child: Builder(
                          builder: (context) {
                            final isLight =
                                Theme.of(context).brightness ==
                                Brightness.light;
                            final contentColor =
                                isLight ? Colors.white : Colors.black;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      color: contentColor,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Weather data unavailable.',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: contentColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Please check your internet connection or try again later.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: contentColor.withAlpha(
                                                (0.85 * 255).toInt(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _loadingWeather
                                            ? null
                                            : () async {
                                              setState(() {
                                                _loadingWeather = true;
                                              });
                                              await _loadWeather();
                                            },
                                    icon: Icon(Icons.refresh),
                                    label: Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                      : WeatherAdvisoryCard(
                        weather: WeatherUtils.getWeatherDescription(
                          currentHourWeather!['weathercode'],
                        ),
                        temp: '${currentHourWeather!['temperature'].round()}°C',
                        colorScheme: colorScheme,
                        icon: WeatherUtils.getWeatherIcon(
                          WeatherUtils.getWeatherDescription(
                            currentHourWeather!['weathercode'],
                          ),
                        ),
                        location: userLocation ?? '',
                      )),
              const SizedBox(height: 16),

              // Farming Tips Card
              UpcomingTasksCard(colorScheme: colorScheme),
              const SizedBox(height: 16),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _QuickActionCard(
                title: 'Reminders Calendar',
                subtitle: 'View and manage reminders',
                icon: Icons.calendar_today,
                gradient: LinearGradient(
                  colors: [colorScheme.secondary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  await Navigator.pushNamed(
                    this.context,
                    '/reminders_calendar',
                  );
                  if (!mounted) return;
                  setState(() {}); // Refresh reminders after returning
                },
              ),
              const SizedBox(height: 16),
              _QuickActionCard(
                title: 'AI Farming Plans',
                subtitle: 'View your plans',
                icon: Icons.agriculture,
                gradient: LinearGradient(
                  colors: [colorScheme.secondary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  await Navigator.pushNamed(this.context, '/plans_list');
                  if (!mounted) return;
                },
              ),
              const SizedBox(height: 32),

              // Recent Plans
              Text(
                'Recent Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Only the last 2 plans are shown',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _plansService.getUserPlans(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading plans',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    );
                  }
                  final plans = snapshot.data ?? [];
                  final recentPlans =
                      plans
                          .take(2)
                          .map(
                            (plan) => {
                              'id': plan['id'],
                              'crop': plan['crop'] ?? 'Unknown Crop',
                              'location':
                                  plan['location'] ?? 'Unknown Location',
                              'goal': plan['goal'] ?? 'Unknown Goal',
                              'createdAt':
                                  plan['createdAt']?.toDate() ?? DateTime.now(),
                            },
                          )
                          .toList();

                  if (recentPlans.isEmpty) {
                    return _CreateFirstPlanCard(colorScheme: colorScheme);
                  }

                  return Column(
                    children:
                        recentPlans
                            .map(
                              (plan) => _RecentPlanCard(
                                plan: plan,
                                colorScheme: colorScheme,
                                onTap: () async {
                                  try {
                                    final completePlan = await _plansService
                                        .getPlanById(plan['id']);
                                    if (!mounted) return;
                                    if (completePlan != null) {
                                      Navigator.pushNamed(
                                        this.context,
                                        '/plan_detail',
                                        arguments: completePlan,
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        this.context,
                                        '/plan_detail',
                                        arguments: plan,
                                      );
                                    }
                                  } catch (_) {
                                    if (!mounted) return;
                                    Navigator.pushNamed(
                                      this.context,
                                      '/plan_detail',
                                      arguments: plan,
                                    );
                                  }
                                },
                              ),
                            )
                            .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTextColor = isLight ? Colors.white : Colors.black87;
    final cardSubTextColor =
        isLight
            ? Colors.white.withAlpha((0.8 * 255).toInt())
            : Colors.black.withAlpha((0.7 * 255).toInt());

    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          gradient: gradient,
          borderColor: Theme.of(
            context,
          ).colorScheme.primary.withAlpha((0.2 * 255).toInt()),
          borderWidth: 1.5,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.06 * 255).toInt()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          child: Row(
            children: [
              Icon(icon, color: cardTextColor, size: 32),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: cardSubTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: cardTextColor.withAlpha((0.7 * 255).toInt()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _RecentPlanCard({
    required this.plan,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = plan['createdAt'] as DateTime;
    final timeAgo = _getTimeAgo(createdAt);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                Theme.of(
                  context,
                ).colorScheme.surface.withAlpha((0.05 * 255).toInt()),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: Theme.of(
              context,
            ).colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            borderWidth: 1.5,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.06 * 255).toInt()),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.agriculture,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['crop'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['location'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((0.8 * 255).toInt()),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['goal'],
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: colorScheme.primary.withAlpha((0.7 * 255).toInt()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _CreateFirstPlanCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _CreateFirstPlanCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTextColor = isLight ? Colors.white : Colors.black87;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      gradient: LinearGradient(
        colors: [colorScheme.primary, colorScheme.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withAlpha((0.2 * 255).toInt()),
      borderWidth: 1,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((0.1 * 255).toInt()),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cardTextColor, size: 36),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start with AI Smart Farming',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cardTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create your first plan to get personalized farming recommendations!',
                  style: TextStyle(
                    fontSize: 14,
                    color: cardTextColor.withAlpha((0.9 * 255).toInt()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherAdvisoryCard extends StatelessWidget {
  final String weather;
  final String temp;
  final ColorScheme colorScheme;
  final IconData icon;
  final String? location;

  const WeatherAdvisoryCard({
    super.key,
    required this.weather,
    required this.temp,
    required this.colorScheme,
    required this.icon,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTextColor = isLight ? Colors.white : Colors.black87;
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      gradient: LinearGradient(
        colors: [colorScheme.primary, colorScheme.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withAlpha((0.2 * 255).toInt()),
      borderWidth: 1,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((0.1 * 255).toInt()),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cardTextColor, size: 36),
              const SizedBox(width: 18),
              Text(
                '$weather  |  $temp',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cardTextColor,
                ),
              ),
            ],
          ),
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: cardTextColor.withAlpha((0.85 * 255).toInt()),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location!,
                    style: TextStyle(
                      fontSize: 14,
                      color: cardTextColor.withAlpha((0.85 * 255).toInt()),
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class UpcomingTasksCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final ReminderService _reminderService = ReminderService();

  UpcomingTasksCard({super.key, required this.colorScheme});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDate = DateTime(date.year, date.month, date.day);

    if (reminderDate == today) {
      return 'Today';
    } else if (reminderDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTextColor = isLight ? Colors.white : Colors.black87;
    return FutureBuilder<List<Reminder>>(
      future: _reminderService.getNextReminders(3),
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? [];
        return GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
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
                  Icon(Icons.event_note, color: cardTextColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Upcoming Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cardTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(cardTextColor),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Loading reminders...',
                      style: TextStyle(color: cardTextColor),
                    ),
                  ],
                )
              else if (reminders.isEmpty)
                Text(
                  'No upcoming tasks. Add reminders in the Reminders Calendar!',
                  style: TextStyle(fontSize: 16, color: cardTextColor),
                )
              else
                ...reminders.map(
                  (reminder) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          color: cardTextColor.withAlpha((0.8 * 255).toInt()),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(reminder.date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cardTextColor.withAlpha(
                                  (0.9 * 255).toInt(),
                                ),
                              ),
                            ),
                            Text(
                              reminder.time.format(context),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cardTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reminder.text,
                            style: TextStyle(
                              color: cardTextColor,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
