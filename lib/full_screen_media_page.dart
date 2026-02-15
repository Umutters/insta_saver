import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class FullScreenMediaPage extends StatefulWidget {
  final String filePath; // Dosyanın telefondaki konumu
  final bool isVideo; // Video mu fotoğraf mı?

  const FullScreenMediaPage({
    Key? key,
    required this.filePath,
    required this.isVideo,
  }) : super(key: key);

  @override
  State<FullScreenMediaPage> createState() => _FullScreenMediaPageState();
}

class _FullScreenMediaPageState extends State<FullScreenMediaPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideoPlayer();
    }
  }

  // Video oynatıcıyı kuran fonksiyon
  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.filePath));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true, // Açılır açılmaz başlasın
      looping: true, // Instagram Reels gibi başa sarsın
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {}); // Arayüzü güncelle
  }

  @override
  void dispose() {
    // Sayfa kapanırken hafızayı temizle (Çok önemli!)
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Arka plan tam ekran hissiyatı için siyah
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar şeffaf
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true, // Resmi/Videoyu AppBar'ın altına kadar uzat

      body: Center(
        child: widget.isVideo ? _buildVideoPlayer() : _buildImageViewer(),
      ),
    );
  }

  // VİDEO OYNATICI ARAYÜZÜ
  Widget _buildVideoPlayer() {
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    } else {
      return const CircularProgressIndicator(
        color: Colors.white,
      ); // Yükleniyor animasyonu
    }
  }

  // FOTOĞRAF GÖSTERİCİ ARAYÜZÜ (Zoom özellikli)
  Widget _buildImageViewer() {
    return InteractiveViewer(
      panEnabled: true, // Kaydırma
      minScale: 1.0, // Normal boyutu
      maxScale: 4.0, // 4 kata kadar zoom yapılabilir
      child: Image.file(
        File(widget.filePath),
        fit: BoxFit.contain, // Ekranı taşmadan sığdır
      ),
    );
  }
}
