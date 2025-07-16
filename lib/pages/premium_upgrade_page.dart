import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_gradients.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage> {
  bool _isProcessing = false;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _generatedCode;

  bool _isValidPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return RegExp(r'^(2567\d{8}|07\d{8})$').hasMatch(cleanPhone);
  }

  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '256${cleanPhone.substring(1)}';
    }
    return cleanPhone;
  }

  void _generateConfirmationCode() {
    _generatedCode = (1000 + DateTime.now().millisecond % 9000).toString();
  }

  Future<void> _startSimulatedPayment() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Enter Your Phone Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We\'ll send a confirmation code to verify your payment',
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                _phoneController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  _isProcessing
                      ? null
                      : () async {
                        if (_phoneController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your phone number'),
                            ),
                          );
                          return;
                        }
                        if (!_isValidPhoneNumber(_phoneController.text)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid Uganda phone number',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
              child:
                  _isProcessing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Send Code'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (result == true) {
      await _processPayment();
      if (!mounted) return;
    }
  }

  Future<void> _processPayment() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }
    if (!_isValidPhoneNumber(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Uganda phone number'),
        ),
      );
      return;
    }
    setState(() => _isProcessing = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upgrade.')),
      );
      return;
    }
    try {
      _generateConfirmationCode();
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _showConfirmationDialog();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isProcessing = false);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Enter Confirmation Code'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'A confirmation code has been sent to ${_formatPhoneNumber(_phoneController.text)}',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Code: $_generatedCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter 4-digit code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _isProcessing = true);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _verifyCode,
                child: const Text('Verify'),
              ),
            ],
          ),
    );
  }

  Future<void> _verifyCode() async {
    if (_codeController.text == _generatedCode) {
      Navigator.of(context).pop();
      setState(() => _isProcessing = true);
      final user = FirebaseAuth.instance.currentUser;
      try {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        await FirebaseFirestore.instance.collection('premium_requests').add({
          'userId': user!.uid,
          'userEmail': user.email,
          'userName': user.displayName ?? 'Unknown User',
          'phoneNumber': _formatPhoneNumber(_phoneController.text),
          'status': 'pending',
          'requestedAt': Timestamp.now(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your request has been received! Once approved by the admin, you will have premium access for 1 hour.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid confirmation code')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Upgrade to Premium',
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 32),
                    Icon(Icons.star, color: Colors.amber, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Go Premium',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unlock all features for just 1,000 UGX/hour:',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildBenefit(
                      Icons.psychology,
                      'Unlimited AI plan generation',
                    ),
                    const SizedBox(height: 16),
                    _buildBenefit(Icons.chat, 'Unlimited AI chat requests'),
                    const SizedBox(height: 16),
                    _buildBenefit(Icons.lock_open, 'No daily limits'),
                    const SizedBox(height: 16),
                    _buildBenefit(
                      Icons.verified,
                      'Premium badge on your profile',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Pay with Mobile Money'),
                        onPressed: _startSimulatedPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: colorScheme.primary, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
