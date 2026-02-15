import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                              'İnstaSaver',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Made by Umutters',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Instagram Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Instructions
                        const Text(
                          'enter url to download content in here',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Post, Reels veya Story linki',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),

                        const SizedBox(height: 30),

                        // URL Input
                        ScaleTransition(
                          scale: _animation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'https://www.instagram.com/p/...',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste),
                                  onPressed: _pasteFromClipboard,
                                  color: const Color(0xFF833AB4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        // Download Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _downloadMedia,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF833AB4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${(_downloadProgress * 100).toInt()}%',
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.download),
                                      SizedBox(width: 8),
                                      Text(
                                        'İndir',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
