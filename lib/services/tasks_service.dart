import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TasksService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Add a new task to a plan
  Future<void> addTask(String planId, Map<String, dynamic> task) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .collection('tasks')
          .add({
            ...task,
            'createdAt': Timestamp.now(),
            'isCompleted': false,
            'completedAt': null,
            'userId': user.uid,
          });
    } catch (e) {
      rethrow;
    }
  }

  // Get all tasks for a specific plan
  Stream<List<Map<String, dynamic>>> getPlanTasks(String planId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plans')
        .doc(planId)
        .collection('tasks')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Update a task
  Future<void> updateTask(
    String planId,
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .collection('tasks')
          .doc(taskId)
          .update({...updates, 'updatedAt': Timestamp.now()});
    } catch (e) {
      rethrow;
    }
  }

  // Mark a task as completed
  Future<void> markTaskAsCompleted(String planId, String taskId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'isCompleted': true,
            'completedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      rethrow;
    }
  }

  // Mark a task as incomplete
  Future<void> markTaskAsIncomplete(String planId, String taskId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'isCompleted': false,
            'completedAt': null,
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      rethrow;
    }
  }

  // Delete a task
  Future<void> deleteTask(String planId, String taskId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plans')
          .doc(planId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get task progress for a plan
  Future<Map<String, dynamic>> getPlanProgress(String planId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'total': 0, 'completed': 0, 'percentage': 0.0};

      final tasksSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('plans')
              .doc(planId)
              .collection('tasks')
              .get();

      final tasks = tasksSnapshot.docs;
      final totalTasks = tasks.length;
      final completedTasks =
          tasks.where((doc) => doc.data()['isCompleted'] == true).length;
      final percentage =
          totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;

      return {
        'total': totalTasks,
        'completed': completedTasks,
        'percentage': percentage,
      };
    } catch (e) {
      return {'total': 0, 'completed': 0, 'percentage': 0.0};
    }
  }

  // Add default tasks for a new plan based on crop and goal
  Future<void> addDefaultTasks(String planId, String crop, String goal) async {
    try {
      final defaultTasks = _getDefaultTasksForCrop(crop, goal);

      for (final task in defaultTasks) {
        await addTask(planId, task);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get default tasks based on crop and goal
  List<Map<String, dynamic>> _getDefaultTasksForCrop(String crop, String goal) {
    final baseTasks = [
      {
        'title': 'Soil Preparation',
        'description': 'Prepare the soil for ${crop.toLowerCase()} planting',
        'category': 'preparation',
        'estimatedDuration': 2,
        'priority': 'high',
        'day': 1,
      },
      {
        'title': 'Seed Selection',
        'description': 'Select high-quality seeds for optimal yield',
        'category': 'planning',
        'estimatedDuration': 1,
        'priority': 'high',
        'day': 1,
      },
      {
        'title': 'Planting',
        'description': 'Plant ${crop.toLowerCase()} seeds at optimal spacing',
        'category': 'planting',
        'estimatedDuration': 3,
        'priority': 'high',
        'day': 2,
      },
      {
        'title': 'Initial Watering',
        'description': 'Provide adequate water for seed germination',
        'category': 'irrigation',
        'estimatedDuration': 1,
        'priority': 'high',
        'day': 2,
      },
      {
        'title': 'Fertilizer Application',
        'description':
            'Apply appropriate fertilizers for ${crop.toLowerCase()} growth',
        'category': 'fertilization',
        'estimatedDuration': 2,
        'priority': 'medium',
        'day': 3,
      },
      {
        'title': 'Pest Monitoring',
        'description': 'Monitor for pests and diseases',
        'category': 'monitoring',
        'estimatedDuration': 1,
        'priority': 'medium',
        'day': 4,
      },
      {
        'title': 'Weeding',
        'description': 'Remove weeds to prevent competition',
        'category': 'maintenance',
        'estimatedDuration': 2,
        'priority': 'medium',
        'day': 5,
      },
      {
        'title': 'Harvest Preparation',
        'description': 'Prepare for ${crop.toLowerCase()} harvest',
        'category': 'harvest',
        'estimatedDuration': 1,
        'priority': 'high',
        'day': 6,
      },
    ];

    // Add goal-specific tasks
    if (goal == 'Organic Farming') {
      baseTasks.addAll([
        {
          'title': 'Organic Certification Check',
          'description': 'Ensure all practices meet organic standards',
          'category': 'certification',
          'estimatedDuration': 1,
          'priority': 'high',
          'day': 1,
        },
        {
          'title': 'Natural Pest Control',
          'description': 'Implement natural pest control methods',
          'category': 'pest_control',
          'estimatedDuration': 2,
          'priority': 'medium',
          'day': 4,
        },
      ]);
    } else if (goal == 'Water Conservation') {
      baseTasks.addAll([
        {
          'title': 'Drip Irrigation Setup',
          'description': 'Install drip irrigation system for water efficiency',
          'category': 'irrigation',
          'estimatedDuration': 3,
          'priority': 'high',
          'day': 2,
        },
        {
          'title': 'Mulching',
          'description': 'Apply mulch to reduce water evaporation',
          'category': 'soil_conservation',
          'estimatedDuration': 2,
          'priority': 'medium',
          'day': 3,
        },
      ]);
    }

    return baseTasks;
  }
}
