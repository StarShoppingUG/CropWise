import 'package:flutter/material.dart';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../widgets/map_picker.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/primary_crops_selector.dart';
import '../../services/user_service.dart';
import '../../constants/crop_constants.dart';
import '../widgets/custom_app_bar.dart';
import '../../main.dart';
import 'package:provider/provider.dart';
import '../models/location_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _professionController = TextEditingController();
  final _locationController = TextEditingController();
  final UserService _userService = UserService();

  ImageProvider? _profileImage;
  String? _selectedAvatarAsset;
  List<String> _primaryCrops = [];
  final List<String> _allCrops = CropConstants.crops;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProfile = await _userService.getUserProfile();
    if (userProfile != null) {
      setState(() {
        _nameController.text = userProfile['name'] ?? 'User';
        _professionController.text = userProfile['profession'] ?? 'Farmer';
        _locationController.text = userProfile['location'] ?? '';
        _primaryCrops = List<String>.from(userProfile['primaryCrops'] ?? []);
        _selectedAvatarAsset = userProfile['avatarAsset'];
        _profileImage =
            _selectedAvatarAsset != null
                ? AssetImage(_selectedAvatarAsset!)
                : null;
      });
    }
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

  void _showEditProfilePictureDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AvatarPicker(
            selectedAvatarAsset: _selectedAvatarAsset,
            onAvatarSelected: (asset) {
              setState(() {
                _profileImage = AssetImage(asset);
                _selectedAvatarAsset = asset;
              });
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

  bool get _canFinishOnboarding {
    return _nameController.text.trim().isNotEmpty &&
        _professionController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        _selectedAvatarAsset != null &&
        _primaryCrops.isNotEmpty;
  }

  Future<void> _completeOnboarding() async {
    if (!_canFinishOnboarding) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields before continuing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    try {
      await _userService.updateUserProfile(
        name: _nameController.text,
        profession: _professionController.text,
        location: _locationController.text,
        primaryCrops: _primaryCrops,
        avatarAsset: _selectedAvatarAsset,
        profileComplete: true,
      );
      if (!mounted) return;
      // Update LocationProvider with new location
      Provider.of<LocationProvider>(
        context,
        listen: false,
      ).setLocation(_locationController.text);
      // Reset tab to Dashboard before navigating home
      Provider.of<NavigationNotifier>(context, listen: false).setIndex(0);
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing onboarding: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Complete Your Profile',
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          leading: const SizedBox.shrink(),
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
                          'Full Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Enter your name'
                                      : null,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.person,
                              color: colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface.withAlpha(
                              (0.7 * 255).toInt(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Profession',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _professionController,
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Enter your profession'
                                      : null,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.work,
                              color: colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface.withAlpha(
                              (0.7 * 255).toInt(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Farm Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                  child: Text(
                                    _locationController.text.isEmpty
                                        ? 'No location selected'
                                        : _locationController.text,
                                    style: TextStyle(
                                      color:
                                          _locationController.text.isEmpty
                                              ? colorScheme.onSurface.withAlpha(
                                                (0.5 * 255).toInt(),
                                              )
                                              : colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Primary Crops',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showCropSelector,
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
                                    Icons.eco,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _primaryCrops.isEmpty
                                        ? 'None selected'
                                        : _primaryCrops.join(', '),
                                    style: TextStyle(
                                      color:
                                          _primaryCrops.isEmpty
                                              ? colorScheme.onSurface.withAlpha(
                                                (0.5 * 255).toInt(),
                                              )
                                              : colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _canFinishOnboarding
                                    ? _completeOnboarding
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Finish',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
