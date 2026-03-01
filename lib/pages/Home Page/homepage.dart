import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:insta_downloader/pages/Home%20Page/Home%20Page%20Widgets/app_icon.dart';
import 'package:insta_downloader/pages/Home%20Page/Home%20Page%20Widgets/custom_button.dart';
import 'package:insta_downloader/pages/Home%20Page/Home%20Page%20Widgets/custom_text_field.dart';
import 'package:insta_downloader/widgets/header.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:insta_downloader/services/instagram_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final InstagramService _instagramService = InstagramService();
  bool _isLoading = false;
  double _downloadProgress = 0.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
      // 1.0'dan 1.05'e çok hafif bir büyüme
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _requestPermissions();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.photos.request();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _urlController.text = clipboardData.text!;
      });
      _animationController.forward().then(
        (_) => _animationController.reverse(),
      );
    }
  }

  Future<void> _downloadMedia() async {
    if (_urlController.text.isEmpty) {
      _showSnackBar('Lütfen bir Instagram linki girin', Colors.orange);
      return;
    }

    if (!_urlController.text.contains('instagram.com')) {
      _showSnackBar('Geçerli bir Instagram linki girin', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Medya bilgilerini al
      final mediaInfo = await _instagramService.getMediaInfoAlternative(
        _urlController.text,
      );

      if (mediaInfo == null) {
        _showSnackBar(
          'Medya bilgileri alınamadı. API key ekleyin.',
          Colors.red,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Demo amaçlı - gerçek uygulamada API'den gelen URL kullanılacak
      // Şimdilik örnek bir resim indirelim
      const demoImageUrl = 'https://picsum.photos/1080/1080';

      // Dosya kaydetme yolu
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savePath = '${directory.path}/instagram_$timestamp.jpg';

      // İndir
      final result = await _instagramService.downloadMedia(
        demoImageUrl,
        savePath,
        (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (result != null) {
        // Galeriye kaydet
        try {
          await Gal.putImage(result);
          _showSnackBar('✓ İndirme tamamlandı!', Colors.green);
          _urlController.clear();
        } catch (e) {
          _showSnackBar(
            'Galeriye kaydedilemedi: ${e.toString()}',
            Colors.orange,
          );
        }
      } else {
        _showSnackBar('İndirme başarısız', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Hata: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Align(
                alignment: Alignment.centerLeft,
                child: AppHeader(
                  title: "Made by Umutters",
                  subtitle: "Insta Saver",
                ),
              ),
              // Main Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Instagram Icon
                    const AppIcon(),
                    const SizedBox(height: 30),

                    // Instructions
                    const Text(
                      'içeriği indirmek için url giriniz',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Post, Reels veya Story linki',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),

                    const SizedBox(height: 40),

                    // URL Input
                    CustomTextField(
                      pasteFromClipBoard: _pasteFromClipboard,
                      animation: _animation,
                      urlController: _urlController,
                    ),
                    SizedBox(height: 40),
                    // Download Button
                    CustomButton(
                      downloadMedia: _downloadMedia,
                      downloadProgress: _downloadProgress,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
