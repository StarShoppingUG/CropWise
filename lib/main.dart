import 'package:crop_wise/pages/ask_page.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:crop_wise/widgets/main_scaffold.dart';
import 'package:crop_wise/pages/weather_page.dart';
import 'package:crop_wise/pages/profile_page.dart';
import 'package:crop_wise/pages/edit_profile_page.dart';
import 'package:crop_wise/pages/task_detail_page.dart';
import 'package:crop_wise/pages/login_page.dart';
import 'package:crop_wise/pages/signup_page.dart';
import 'package:crop_wise/pages/forgot_password_page.dart';
import 'package:crop_wise/pages/plans_list_page.dart';
import 'package:crop_wise/pages/plan_detail_page.dart';
import 'package:crop_wise/pages/farming_plan_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:crop_wise/pages/reminders_calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crop_wise/services/notification_service.dart';
import 'package:crop_wise/pages/onboarding_screen.dart';
import 'package:crop_wise/services/user_service.dart';
import 'models/location_provider.dart';
import 'package:crop_wise/pages/premium_upgrade_page.dart';

class NavigationNotifier extends ChangeNotifier {
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}

class ThemeNotifier extends ChangeNotifier {
  String _themeMode = 'system';
  String get themeMode => _themeMode;

  ThemeNotifier() {
    _loadTheme();
  }

  void setThemeMode(String mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getString('theme_mode') ?? 'system';
    notifyListeners();
  }
}

class AuthMessageNotifier extends ChangeNotifier {
  String? _message;
  Color _messageColor = Colors.green;
  bool _isSigningUp = false;

  String? get message => _message;
  Color get messageColor => _messageColor;
  bool get isSigningUp => _isSigningUp;

  void setSigningUp(bool value) {
    _isSigningUp = value;
  }

  void showMessage(String msg, {bool isError = false}) {
    _message = msg;
    _messageColor = isError ? Colors.red : Colors.green;
    notifyListeners();
  }

  void clearMessage() {
    _message = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    // Continue with app initialization even if Firebase fails
  }

  // Initialize notification service
  await NotificationService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider(create: (_) => NavigationNotifier()),
          ChangeNotifierProvider(create: (_) => AuthMessageNotifier()),
        ],
        child: const CropWiseApp(),
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final navNotifier = Provider.of<NavigationNotifier>(context);
    return MainScaffold(
      onThemeChanged: (mode) => themeNotifier.setThemeMode(mode),
      currentThemeMode: themeNotifier.themeMode,
      selectedTabIndex: navNotifier.selectedIndex,
      onTabChanged: (index) => navNotifier.setIndex(index),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  bool _isLoading = true;
  bool _needsOnboarding = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    // Listen to auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) async {
      // Capture providers before any await
      final navNotifier = Provider.of<NavigationNotifier>(
        context,
        listen: false,
      );
      final authNotifier = Provider.of<AuthMessageNotifier>(
        context,
        listen: false,
      );
      // If a signup is in progress, ignore all auth changes until it's done.
      if (authNotifier.isSigningUp) {
        return;
      }

      if (user != null && _currentUser == null) {
        navNotifier.setIndex(0);
        if (authNotifier.message == 'signup_success') {
          authNotifier.showMessage('Account created successfully!');
        } else {
          authNotifier.showMessage('Login successful!');
        }
      }

      bool needsOnboarding = false;
      if (user != null) {
        final userProfile = await UserService().getUserProfile();
        needsOnboarding = userProfile?['profileComplete'] != true;
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
          _needsOnboarding = needsOnboarding;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser != null) {
      if (_needsOnboarding) {
        return const OnboardingScreen();
      }
      return const AppShell();
    }

    return const LoginPage();
  }
}

class CropWiseApp extends StatelessWidget {
  const CropWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'CropWise',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181A20),
      ),
      themeMode:
          themeNotifier.themeMode == 'dark'
              ? ThemeMode.dark
              : themeNotifier.themeMode == 'light'
              ? ThemeMode.light
              : ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const AppShell(),
        '/plan': (context) => const FarmingPlanPage(),
        '/weather': (context) => const WeatherPage(),
        '/profile': (context) {
          final themeNotifier = Provider.of<ThemeNotifier>(context);
          return ProfilePage(
            onThemeChanged: (mode) => themeNotifier.setThemeMode(mode),
            currentThemeMode: themeNotifier.themeMode,
          );
        },
        '/edit_profile': (context) => const EditProfilePage(),
        '/task_detail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return TaskDetailPage(task: args);
        },
        '/plans_list': (context) => const PlansListPage(),
        '/plan_detail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PlanDetailPage(plan: args);
        },
        '/farming_plan': (context) => const FarmingPlanPage(),
        '/ask': (context) => const AskPage(),
        '/reminders_calendar': (context) => const RemindersCalendarPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/premium_upgrade_page': (context) => const PremiumUpgradePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
