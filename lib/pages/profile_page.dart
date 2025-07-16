import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_service.dart';
import 'premium_requests_admin_page.dart';
import '../secrets.dart';

// Displays the user's profile information and settings.
class ProfilePage extends StatefulWidget {
  final void Function(String themeMode)? onThemeChanged;
  final String? currentThemeMode;
  const ProfilePage({super.key, this.onThemeChanged, this.currentThemeMode});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  final UserService _userService = UserService();
  Stream<DocumentSnapshot>? _userStream;

  @override
  bool get wantKeepAlive => false; // Don't keep alive to ensure fresh data

  @override
  void initState() {
    super.initState();
    _initializeUserStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force refresh when dependencies change (like when navigating back to this page)
    _initializeUserStream();
  }

  void _initializeUserStream() {
    final user = _userService.currentUser;
    if (user != null) {
      _userStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (Route<dynamic> route) => false,
                    );
                  }
                },
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _userService.currentUser;

    return Container(
      decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, snapshot) {
            // Default values if no data
            String userName = 'User';
            String userProfession = 'Farmer';
            String userLocation = 'Not set';
            List<String> primaryCrops = [];

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                userName = data['name'] ?? 'User';
                userProfession = data['profession'] ?? 'Farmer';
                userLocation = data['location'] ?? 'Not set';
                primaryCrops = List<String>.from(data['primaryCrops'] ?? []);
              }
            }

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {}
            }

            // Membership status
            String membershipStatus = 'basic';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data['membershipStatus'] != null) {
                membershipStatus = data['membershipStatus'];
              }
            }

            // Membership status and expiry
            DateTime? premiumUntil;
            bool needsRevertToBasic = false;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data['premiumUntil'] != null) {
                final ts = data['premiumUntil'];
                if (ts is Timestamp) premiumUntil = ts.toDate();
                if (data['isPremium'] == true &&
                    premiumUntil != null &&
                    premiumUntil.isBefore(DateTime.now())) {
                  needsRevertToBasic = true;
                }
              }
            }
            if (needsRevertToBasic && user != null) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'isPremium': false, 'membershipStatus': 'basic'});
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Membership status row (centered in a Card with elevation)
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: colorScheme.surfaceContainerHighest
                                .withAlpha((0.85 * 255).toInt()),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        membershipStatus == 'premium'
                                            ? Icons.star
                                            : Icons.lock,
                                        color:
                                            membershipStatus == 'premium'
                                                ? Colors.amber
                                                : colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        membershipStatus == 'premium'
                                            ? 'Premium Member'
                                            : 'Basic Member',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      if (membershipStatus == 'basic') ...[
                                        const SizedBox(width: 12),
                                        OutlinedButton(
                                          onPressed: () {
                                            Navigator.of(context).pushNamed(
                                              '/premium_upgrade_page',
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: colorScheme.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                          ),
                                          child: const Text('Upgrade'),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (membershipStatus == 'premium' &&
                                      premiumUntil != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Expires: '
                                      '${premiumUntil.year}-${premiumUntil.month.toString().padLeft(2, '0')}-${premiumUntil.day.toString().padLeft(2, '0')} '
                                      '${premiumUntil.hour.toString().padLeft(2, '0')}:${premiumUntil.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withAlpha(
                                          (0.7 * 255).toInt(),
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                    _PremiumCountdown(expiry: premiumUntil),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withAlpha(
                                    (0.4 * 255).toInt(),
                                  ),
                                  colorScheme.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: FutureBuilder<String?>(
                              future: UserService().loadAvatar(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage:
                                        AssetImage(snapshot.data!)
                                            as ImageProvider,
                                  );
                                } else {
                                  return CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.transparent,
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: colorScheme.onPrimary,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userProfession,
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface.withAlpha(
                                (0.7 * 255).toInt(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(
                                (0.6 * 255).toInt(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: Icon(Icons.edit, color: colorScheme.primary),
                            label: Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: colorScheme.primary,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/edit_profile',
                              );
                              if (result == true) {
                                setState(() {}); // Optionally trigger a rebuild
                              }
                            },
                          ),
                          // ADMIN BUTTON
                          if (user != null && user.email == email) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('Admin: Premium Requests'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 18,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const PremiumRequestsAdminPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Farm Information
                    Text(
                      'Farm Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Farm Location',
                      subtitle: userLocation,
                      icon: Icons.location_on,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Primary Crops',
                      subtitle:
                          primaryCrops.isEmpty
                              ? 'None selected'
                              : primaryCrops.join(', '),
                      icon: Icons.eco,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 32),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.logout, color: colorScheme.error),
                        label: Text(
                          'Logout',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error.withAlpha(
                            (0.22 * 255).toInt(),
                          ),
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _handleLogout,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ColorScheme colorScheme;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
      borderColor: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
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
              color: colorScheme.primary.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
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

class _PremiumCountdown extends StatefulWidget {
  final DateTime expiry;
  const _PremiumCountdown({required this.expiry});
  @override
  State<_PremiumCountdown> createState() => _PremiumCountdownState();
}

class _PremiumCountdownState extends State<_PremiumCountdown> {
  late Duration _remaining;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiry.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final newRemaining = widget.expiry.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = newRemaining;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox();
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    return Text(
      'Premium ends in: '
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
