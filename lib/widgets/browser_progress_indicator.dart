import 'package:flutter/material.dart';

class BrowserProgressIndicator extends StatelessWidget {
  final double progress;

  const BrowserProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% İndiriliyor...',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
