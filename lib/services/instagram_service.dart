import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class InstagramService {
  final Dio _dio = Dio();

  // Instagram medya bilgilerini al
  Future<Map<String, dynamic>?> getMediaInfo(String url) async {
    try {
      // RapidAPI - Instagram Downloader API kullanımı
      // Not: Kendi API key'inizi almanız gerekiyor (rapidapi.com'dan)

      final response = await http.post(
        Uri.parse(
          'https://instagram-downloader-download-instagram-videos-stories.p.rapidapi.com/index',
        ),
        headers: {
          'content-type': 'application/json',
          'X-RapidAPI-Key':
              'YOUR_RAPIDAPI_KEY_HERE', // Buraya kendi API key'inizi ekleyin
          'X-RapidAPI-Host':
              'instagram-downloader-download-instagram-videos-stories.p.rapidapi.com',
        },
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      return null;
    } catch (e) {
      print('Hata: $e');
      return null;
    }
  }

  // Alternatif: Public API kullanımı (API key gerektirmez ama daha az güvenilir)
  Future<Map<String, dynamic>?> getMediaInfoAlternative(String url) async {
    try {
      // Instagram post/reel/story ID'sini URL'den çıkar
      String? shortcode = extractShortcode(url);
      if (shortcode == null) return null;

      // Instagram Graph API veya web scraping kullanabilirsiniz
      // Bu basitleştirilmiş bir örnektir
      return {
        'type': 'video', // veya 'image', 'carousel'
        'url': url,
        'shortcode': shortcode,
        'thumbnail': 'https://via.placeholder.com/300',
      };
    } catch (e) {
      print('Hata: $e');
      return null;
    }
  }

  String? extractShortcode(String url) {
    // Instagram URL formatları:
    // https://www.instagram.com/p/SHORTCODE/
    // https://www.instagram.com/reel/SHORTCODE/
    // https://www.instagram.com/stories/USERNAME/STORYID/

    final regexPost = RegExp(r'instagram\.com/p/([a-zA-Z0-9_-]+)');
    final regexReel = RegExp(r'instagram\.com/reel/([a-zA-Z0-9_-]+)');

    var match = regexPost.firstMatch(url);
    if (match != null) return match.group(1);

    match = regexReel.firstMatch(url);
    if (match != null) return match.group(1);

    return null;
  }

  // Dosyayı indir
  Future<String?> downloadMedia(
    String mediaUrl,
    String savePath,
    Function(double) onProgress,
  ) async {
    try {
      await _dio.download(
        mediaUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            onProgress(progress);
          }
        },
      );
      return savePath;
    } catch (e) {
      print('İndirme hatası: $e');
      return null;
    }
  }
}
