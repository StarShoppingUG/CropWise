import 'package:flutter/material.dart';

class CropWiseLogo extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? padding;

  const CropWiseLogo({super.key, this.size = 80, this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.only(bottom: 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withAlpha((0.90 * 255).toInt()),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon/CropWiseLogo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
