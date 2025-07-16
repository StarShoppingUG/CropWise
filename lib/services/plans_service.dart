import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlansService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Utility to recursively flatten all arrays in a map
  dynamic _flattenArrays(dynamic value) {
    if (value is List) {
      // Flatten any nested lists
      return value.expand((e) => e is List ? _flattenArrays(e) : [e]).toList();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _flattenArrays(v)));
    } else {
      return value;
    }
  }

  // Save a new plan to Firestore
  Future<String> savePlan(Map<String, dynamic> plan) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Flatten arrays before saving
      final flatPlan = _flattenArrays(plan);
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .add({
            ...flatPlan,
            'createdAt': Timestamp.now(),
            'userId': user.uid,
            'isActive': true,
          });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get all plans for the current user
  Stream<List<Map<String, dynamic>>> getUserPlans() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Get a specific plan by ID
  Future<Map<String, dynamic>?> getPlanById(String planId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('plans')
              .doc(planId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update a plan
  Future<void> updatePlan(String planId, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .update({...updates, 'updatedAt': Timestamp.now()});
    } catch (e) {
      rethrow;
    }
  }

  // Delete a plan
  Future<void> deletePlan(String planId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // Mark a plan as completed
  Future<void> markPlanAsCompleted(String planId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .update({
            'isCompleted': true,
            'completedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      rethrow;
    }
  }

  // Get active plans (not completed)
  Stream<List<Map<String, dynamic>>> getActivePlans() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .where('isCompleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Get completed plans
  Stream<List<Map<String, dynamic>>> getCompletedPlans() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .where('isCompleted', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }
}
