import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../widgets/app_gradients.dart';
import '../widgets/map_picker.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/primary_crops_selector.dart';
import '../../services/user_service.dart';
import '../../constants/crop_constants.dart';
import '../models/location_provider.dart';
import 'package:provider/provider.dart';

// Edit Profile Page allowing users to update their profile.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _professionController = TextEditingController();
  final _locationController = TextEditingController();
  final UserService _userService = UserService();

  ImageProvider? _profileImage;
  String? _selectedAvatarAsset;

  List<String> _primaryCrops = List.empty();
  final List<String> _allCrops = CropConstants.crops;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null) {
        setState(() {
          _nameController.text = userProfile['name'] ?? 'User';
          _professionController.text = userProfile['profession'] ?? 'Farmer';
          _locationController.text = userProfile['location'] ?? 'Not set';
          _primaryCrops = List<String>.from(userProfile['primaryCrops'] ?? []);
          _selectedAvatarAsset = userProfile['avatarAsset'];
          _profileImage =
              _selectedAvatarAsset != null
                  ? AssetImage(_selectedAvatarAsset!)
                  : null;
        });
      }
    } catch (_) {
      setState(() {
        _profileImage = null;
        _selectedAvatarAsset = null;
      });
      _showError('Error loading user data.');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
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
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              backgroundColor: colorScheme.primary.withAlpha(
                (0.85 * 255).toInt(),
              ),
              foregroundColor: colorScheme.onPrimary,
              centerTitle: true,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: 24.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _showEditProfilePictureDialog,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
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
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: _profileImage,
                                  child:
                                      _profileImage == null
                                          ? Icon(
                                            Icons.person,
                                            size: 50,
                                            color: colorScheme.onPrimary,
                                          )
                                          : null,
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap avatar to edit',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Edit your profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _GlassTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 18),
                      _GlassTextField(
                        controller: _professionController,
                        label: 'Profession',
                        icon: Icons.work,
                      ),
                      const SizedBox(height: 18),
                      // Location field with map picker
                      GestureDetector(
                        onTap: _showMapPicker,
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withAlpha(
                                    (0.2 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Farm Location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _locationController.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withAlpha(
                                          (0.7 * 255).toInt(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.map,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Primary Crops: ${_primaryCrops.isEmpty ? 'None' : _primaryCrops.join(', ')}',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withAlpha(
                            (0.85 * 255).toInt(),
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: Icon(Icons.edit, color: colorScheme.primary),
                        label: Text(
                          'Edit Primary Crops',
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
                        onPressed: _showCropSelector,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                                shadowColor: colorScheme.primary.withAlpha(
                                  (0.2 * 255).toInt(),
                                ),
                              ),
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    await _userService.updateUserProfile(
                                      name: _nameController.text,
                                      profession: _professionController.text,
                                      location: _locationController.text,
                                      primaryCrops: _primaryCrops,
                                    );
                                    // Update LocationProvider with new location
                                    Provider.of<LocationProvider>(
                                      context,
                                      listen: false,
                                    ).setLocation(_locationController.text);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile updated successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    if (!mounted) return;
                                    Navigator.pop(context, true);
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error updating profile: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(
                                  color: colorScheme.primary,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfilePictureDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AvatarPicker(
            selectedAvatarAsset: _selectedAvatarAsset,
            onAvatarSelected: (asset) async {
              setState(() {
                _profileImage = AssetImage(asset);
                _selectedAvatarAsset = asset;
              });
              await _userService.updateUserProfile(
                name: _nameController.text,
                profession: _professionController.text,
                location: _locationController.text,
                primaryCrops: _primaryCrops,
                avatarAsset: asset,
              );
              _showSuccess('Avatar selected!');
            },
            radius: 36,
          ),
    );
  }

  void _showCropSelector() async {
    showDialog(
      context: context,
      builder:
          (context) => PrimaryCropsSelector(
            selectedCrops: _primaryCrops,
            allCrops: _allCrops,
            onCropsSelected: (selected) {
              setState(() {
                _primaryCrops = selected;
              });
            },
          ),
    );
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
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        colors: [
          colorScheme.surface.withAlpha((0.13 * 255).toInt()),
          colorScheme.surface.withAlpha((0.13 * 255).toInt()),
        ],
      ),
      borderColor: colorScheme.primary.withAlpha((0.18 * 255).toInt()),
      borderWidth: 1.2,
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          if (label == 'Full Name' && value.trim().split(' ').length < 2) {
            return 'Please enter your full name (first and last name)';
          }
          return null;
        },
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: colorScheme.primary),
          labelText: label,
          hintText: label == 'Full Name' ? 'Enter your full name' : null,
          labelStyle: TextStyle(color: colorScheme.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 8,
          ),
        ),
      ),
    );
  }
}
