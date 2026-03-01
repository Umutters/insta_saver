import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.photo_library, size: 80, color: Colors.white),
    );
  }
}
