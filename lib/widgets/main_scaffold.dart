import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/dashboard_page.dart';
import '../pages/weather_page.dart';
import '../pages/profile_page.dart';
import '../pages/farming_plan_page.dart';
import '../pages/ask_page.dart';
import 'package:provider/provider.dart';
import 'package:crop_wise/main.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';

class MainScaffold extends StatefulWidget {
  final void Function(String themeMode) onThemeChanged;
  final String currentThemeMode;
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;

  const MainScaffold({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
    required this.selectedTabIndex,
    required this.onTabChanged,
  });

  @override
  MainScaffoldState createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use a post-frame callback to show snackbar after the build is complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = Provider.of<AuthMessageNotifier>(context, listen: false);
      if (notifier.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.message!),
            backgroundColor: notifier.messageColor,
          ),
        );
        notifier.clearMessage();
      }
    });
  }

  List<Widget> get _pages => [
    DashboardPage(),
    WeatherPage(),
    FarmingPlanPage(),
    const AskPage(),
    ProfilePage(
      onThemeChanged: widget.onThemeChanged,
      currentThemeMode: widget.currentThemeMode,
    ),
  ];

  void _onItemTapped(int index) {
    widget.onTabChanged(index);
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((0.3 * 255).toInt()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.brightness_6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text('Theme'),
                  subtitle: Text(
                    widget.currentThemeMode == 'dark'
                        ? 'Dark'
                        : widget.currentThemeMode == 'light'
                        ? 'Light'
                        : 'System',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeDialog();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.feedback,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text('App Feedback'),
                  subtitle: Text('Send us your thoughts'),
                  onTap: () {
                    Navigator.pop(context);
                    _showFeedbackDialog();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Use System Theme'),
                  value: 'system',
                  groupValue: widget.currentThemeMode,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Light'),
                  value: 'light',
                  groupValue: widget.currentThemeMode,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Dark'),
                  value: 'dark',
                  groupValue: widget.currentThemeMode,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('App Feedback'),
            content: SizedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We value your feedback! Please let us know your thoughts or suggestions.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Type your feedback here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final feedbackText = controller.text.trim();
                  if (feedbackText.isEmpty) return;
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    final userEmail = user?.email ?? 'anonymous';
                    final userId = user?.uid ?? 'anonymous';
                    await FirebaseFirestore.instance
                        .collection('feedback')
                        .add({
                          'feedback': feedbackText,
                          'timestamp': FieldValue.serverTimestamp(),
                          'userEmail': userEmail,
                          'userId': userId,
                        });
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Thank you for your feedback!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to send feedback: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    final titles = [
      'CropWise',
      'Weather & Advisory',
      'Plan',
      'Ask AI',
      'Profile',
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AppBar(
                toolbarHeight: 48,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha((0.85 * 255).toInt()),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                leading: null,
                title: Text(
                  titles[widget.selectedTabIndex],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _showSettingsMenu,
                    ),
                  ),
                ],
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                centerTitle: true,
              ),
            ),
          ),
        ),
        body: IndexedStack(index: widget.selectedTabIndex, children: _pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withAlpha((0.85 * 255).toInt()),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).toInt()),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: widget.selectedTabIndex,
            onDestinationSelected: _onItemTapped,
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withAlpha((0.15 * 255).toInt()),
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.dashboard_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                selectedIcon: Icon(
                  Icons.dashboard,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.cloud_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                selectedIcon: Icon(
                  Icons.cloud,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Weather',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                selectedIcon: Icon(
                  Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.question_answer_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                selectedIcon: Icon(
                  Icons.question_answer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Ask AI',
              ),
              NavigationDestination(
                icon: FutureBuilder<String?>(
                  future: UserService().loadAvatar(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.isNotEmpty) {
                      return CircleAvatar(
                        backgroundImage: AssetImage(snapshot.data!),
                        radius: 16,
                        backgroundColor: Colors.white,
                      );
                    } else {
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade300,
                        child: Icon(Icons.person, color: Colors.grey),
                      );
                    }
                  },
                ),
                selectedIcon: FutureBuilder<String?>(
                  future: UserService().loadAvatar(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.isNotEmpty) {
                      return Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundImage: AssetImage(snapshot.data!),
                          radius: 17,
                          backgroundColor: Colors.white,
                        ),
                      );
                    } else {
                      return Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.grey.shade300,
                          child: Icon(Icons.person, color: Colors.grey),
                        ),
                      );
                    }
                  },
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
