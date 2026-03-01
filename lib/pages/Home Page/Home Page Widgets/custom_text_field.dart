import 'package:flutter/material.dart';
import 'package:insta_downloader/constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.animation,
    required this.urlController,
    required this.pasteFromClipBoard,
  });
  final Animation<double> animation;
  final TextEditingController urlController;
  final Future<void> Function() pasteFromClipBoard;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://www.instagram.com/p/...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: pasteFromClipBoard,
              color: AppColors.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
