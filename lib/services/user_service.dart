import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get profile URL from firestore
  Future<String?> loadAvatar() async {
    final userProfile = await getUserProfile();
    return userProfile?['avatarAsset'];
  }

  // Get membership status (basic or premium)
  Future<String> getMembershipStatus() async {
    final profile = await getUserProfile();
    return profile?['membershipStatus'] ?? 'basic';
  }

  // Upgrade membership to premium
  Future<void> upgradeToPremium() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      await _firestore.collection('users').doc(user.uid).update({
        'membershipStatus': 'premium',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Create or update user profile
  Future<void> updateUserProfile({
    required String name,
    required String profession,
    required String location,
    required List<String> primaryCrops,
    String? avatarAsset,
    bool? profileComplete,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Fetch current profile to preserve membershipStatus, premiumUntil, and profileComplete
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final currentData = doc.data() ?? {};
      final membershipStatus = currentData['membershipStatus'] ?? 'basic';
      final premiumUntil = currentData['premiumUntil'];
      final currentProfileComplete = currentData['profileComplete'] ?? false;

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': name,
        'profession': profession,
        'location': location,
        'primaryCrops': primaryCrops,
        'updatedAt': FieldValue.serverTimestamp(),
        'membershipStatus': membershipStatus,
        if (premiumUntil != null) 'premiumUntil': premiumUntil,
        if (avatarAsset != null) 'avatarAsset': avatarAsset,
        'profileComplete': profileComplete ?? currentProfileComplete,
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // Create initial user profile after signup
  Future<void> createInitialProfile({
    required String name,
    String profession = 'Farmer',
    String location = '',
    List<String> primaryCrops = const [],
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get current device location name for initial farm location
      String initialLocation = location;
      if (initialLocation.isEmpty) {
        initialLocation = await LocationService.getCurrentLocationName();
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': name,
        'profession': profession,
        'location': initialLocation,
        'primaryCrops': primaryCrops,
        'credits': 3, // Give new users 3 free credits
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'membershipStatus': 'basic', // All new users are basic
        'profileComplete': false, // Onboarding not complete
        // No avatar/profile picture set by default
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get user display name (from Firebase Auth or Firestore)
  Future<String> getUserDisplayName() async {
    final user = _auth.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    final profile = await getUserProfile();
    return profile?['name'] ?? 'User';
  }

  // Get user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  // Get user's current credit count
  Future<int> getUserCredits() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['credits'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Update user's credit count
  Future<void> updateUserCredits(int newCreditCount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore.collection('users').doc(user.uid).update({
        'credits': newCreditCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if user is premium
  Future<bool> isPremium() async {
    final profile = await getUserProfile();
    if (profile == null) return false;
    if (profile['membershipStatus'] == 'premium') {
      if (profile['premiumUntil'] != null) {
        final until = (profile['premiumUntil'] as Timestamp).toDate();
        return until.isAfter(DateTime.now());
      }
      return true;
    }
    return false;
  }

  // Set premium for 1 hour from now
  Future<void> setPremiumForAnHour() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      final until = DateTime.now().add(const Duration(hours: 1));
      await _firestore.collection('users').doc(user.uid).update({
        'membershipStatus': 'premium',
        'premiumUntil': until,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Real-time user document stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // --- Daily Usage Tracking for Chat and Plan Limits ---

  /// Checks and increments the daily chat count for the user. Returns true if under limit, false if limit reached.
  Future<bool> checkAndIncrementDailyChatLimit({int chatLimit = 5}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final usageRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('limits');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usageSnap = await usageRef.get();
    int dailyChatCount = 0;
    String lastChatDate = '';
    if (usageSnap.exists) {
      final data = usageSnap.data()!;
      dailyChatCount = data['dailyChatCount'] ?? 0;
      lastChatDate = data['lastChatDate'] ?? '';
    }
    if (lastChatDate != today) {
      await usageRef.set({
        'dailyChatCount': 1,
        'lastChatDate': today,
      }, SetOptions(merge: true));
      return true;
    } else if (dailyChatCount < chatLimit) {
      await usageRef.update({'dailyChatCount': dailyChatCount + 1});
      return true;
    } else {
      return false;
    }
  }

  /// Checks if the user has reached the daily chat limit (does not increment).
  Future<bool> isDailyChatLimitReached({int chatLimit = 5}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final usageRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('limits');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usageSnap = await usageRef.get();
    int dailyChatCount = 0;
    String lastChatDate = '';
    if (usageSnap.exists) {
      final data = usageSnap.data()!;
      dailyChatCount = data['dailyChatCount'] ?? 0;
      lastChatDate = data['lastChatDate'] ?? '';
    }
    if (lastChatDate != today) {
      return false;
    } else {
      return dailyChatCount >= chatLimit;
    }
  }

  /// Checks and increments the daily plan count for the user. Returns true if under limit, false if limit reached.
  Future<bool> checkAndIncrementDailyPlanLimit({int planLimit = 1}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final usageRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('limits');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usageSnap = await usageRef.get();
    int dailyPlanCount = 0;
    String lastPlanDate = '';
    if (usageSnap.exists) {
      final data = usageSnap.data()!;
      dailyPlanCount = data['dailyPlanCount'] ?? 0;
      lastPlanDate = data['lastPlanDate'] ?? '';
    }
    if (lastPlanDate != today) {
      await usageRef.set({
        'dailyPlanCount': 1,
        'lastPlanDate': today,
      }, SetOptions(merge: true));
      return true;
    } else if (dailyPlanCount < planLimit) {
      await usageRef.update({'dailyPlanCount': dailyPlanCount + 1});
      return true;
    } else {
      return false;
    }
  }

  /// Checks if the user has reached the daily plan limit (does not increment).
  Future<bool> isDailyPlanLimitReached({int planLimit = 1}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final usageRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('limits');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usageSnap = await usageRef.get();
    int dailyPlanCount = 0;
    String lastPlanDate = '';
    if (usageSnap.exists) {
      final data = usageSnap.data()!;
      dailyPlanCount = data['dailyPlanCount'] ?? 0;
      lastPlanDate = data['lastPlanDate'] ?? '';
    }
    if (lastPlanDate != today) {
      return false;
    } else {
      return dailyPlanCount >= planLimit;
    }
  }
}
