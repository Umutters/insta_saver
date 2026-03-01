import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFFD1D1D),
                  Color(0xFFFCAF45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFFD1D1D),
                  Color(0xFFFCAF45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
