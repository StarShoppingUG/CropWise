import 'package:flutter/material.dart';

class AvatarPicker extends StatelessWidget {
  final String? selectedAvatarAsset;
  final ValueChanged<String> onAvatarSelected;
  final double radius;

  static const List<String> avatarAssets = [
    'assets/avatars/avatar1.jpg',
    'assets/avatars/avatar2.jpg',
    'assets/avatars/avatar3.jpg',
    'assets/avatars/avatar4.jpg',
    'assets/avatars/avatar5.jpg',
    'assets/avatars/avatar6.jpg',
    'assets/avatars/avatar7.jpg',
    'assets/avatars/avatar8.jpg',
    'assets/avatars/avatar9.jpg',
    'assets/avatars/avatar10.jpg',
    'assets/avatars/avatar11.jpg',
    'assets/avatars/avatar12.jpg',
  ];

  const AvatarPicker({
    super.key,
    required this.selectedAvatarAsset,
    required this.onAvatarSelected,
    this.radius = 36,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick an Avatar'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: avatarAssets.length,
          itemBuilder: (context, index) {
            final asset = avatarAssets[index];
            return GestureDetector(
              onTap: () {
                onAvatarSelected(asset);
                Navigator.pop(context);
              },
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage(asset),
                child:
                    selectedAvatarAsset == asset
                        ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        )
                        : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
