import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_gradients.dart';

class PremiumRequestsAdminPage extends StatefulWidget {
  const PremiumRequestsAdminPage({super.key});

  @override
  State<PremiumRequestsAdminPage> createState() =>
      _PremiumRequestsAdminPageState();
}

class _PremiumRequestsAdminPageState extends State<PremiumRequestsAdminPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Premium Requests',
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      backgroundColor: null,
      body: Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('premium_requests')
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No premium requests found.',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              );
            }
            final requests = snapshot.data!.docs;
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final data = req.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final requestedAt =
                    (data['requestedAt'] as Timestamp?)?.toDate();
                final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();
                return Card(
                  color: colorScheme.surface,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User: ${data['userName']} (${data['userEmail']})',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        Text(
                          'Phone: ${data['phoneNumber']}',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        Text(
                          'Status: ${status.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                status == 'approved'
                                    ? Colors.green
                                    : status == 'rejected'
                                    ? colorScheme.error
                                    : colorScheme.primary,
                          ),
                        ),
                        if (requestedAt != null)
                          Text(
                            'Requested: ${DateFormat.yMd().add_jm().format(requestedAt)}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(
                                (0.7 * 255).toInt(),
                              ),
                            ),
                          ),
                        if (approvedAt != null)
                          Text(
                            'Approved: ${DateFormat.yMd().add_jm().format(approvedAt)}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(
                                (0.7 * 255).toInt(),
                              ),
                            ),
                          ),
                        if (data['notes'] != null)
                          Text(
                            'Notes: ${data['notes']}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(
                                (0.7 * 255).toInt(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (status == 'pending')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _approveRequest(req.id, data),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _rejectRequest(req.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        if (status == 'approved')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed:
                                    () =>
                                        _revertToBasic(data['userId'], req.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Revert to Basic'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final userId = data['userId'];
    final expiryDate = DateTime.now().add(const Duration(hours: 1));
    final batch = FirebaseFirestore.instance.batch();
    // Update user premium status
    batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
      'isPremium': true,
      'premiumUntil': Timestamp.fromDate(expiryDate),
      'membershipStatus': 'premium',
    });
    // Update request status
    batch.update(
      FirebaseFirestore.instance.collection('premium_requests').doc(requestId),
      {
        'status': 'approved',
        'approvedAt': Timestamp.now(),
        'approvedBy': 'admin', // Optionally use your name/email
      },
    );
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved and user upgraded!')),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('premium_requests')
        .doc(requestId)
        .update({
          'status': 'rejected',
          'approvedAt': Timestamp.now(),
          'approvedBy': 'admin',
        });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request rejected.')));
    }
  }

  Future<void> _revertToBasic(String userId, String requestId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isPremium': false,
      'membershipStatus': 'basic',
    });
    await FirebaseFirestore.instance
        .collection('premium_requests')
        .doc(requestId)
        .update({
          'status': 'reverted',
          'approvedAt': Timestamp.now(),
          'approvedBy': 'admin',
        });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User reverted to basic.')));
    }
  }
}
