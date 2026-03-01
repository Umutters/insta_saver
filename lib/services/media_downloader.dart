import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:insta_downloader/services/instagram_service.dart';
import 'package:insta_downloader/utils/media_utils.dart';

/// Medya indirme işlemlerini yöneten sınıf
class MediaDownloader {
  final InstagramService _instagramService;
  final Function(double) onProgressUpdate;
  final Function(bool) onLoadingStateChange;

  MediaDownloader({
    required InstagramService instagramService,
    required this.onProgressUpdate,
    required this.onLoadingStateChange,
  }) : _instagramService = instagramService;

  /// Seçili medyaları indirir
  Future<DownloadResult> downloadMedias(
    List<Map<String, dynamic>> medias,
  ) async {
    if (medias.isEmpty) {
      return DownloadResult(
        success: false,
        message: 'Hiç medya seçilmedi',
        successCount: 0,
        totalCount: 0,
      );
    }

    onLoadingStateChange(true);

    try {
      int successCount = 0;
      int totalCount = medias.length;

      for (int i = 0; i < medias.length; i++) {
        final media = medias[i];

        // İlerleme güncelle (indirme başlangıcı)
        onProgressUpdate((i + 0.5) / totalCount);

        // Dosya yolu hazırla
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = MediaUtils.getFileExtension(media['type']);
        final fileName = MediaUtils.generateFileName(timestamp, i, extension);
        final savePath = '${directory.path}/$fileName';

        // Medyayı indir
        final result = await _instagramService.downloadMedia(
          media['url'],
          savePath,
          (progress) {
            onProgressUpdate((i + progress) / totalCount);
          },
        );

        // Galeriye kaydet
        if (result != null) {
          try {
            if (media['type'] == 'video') {
              await Gal.putVideo(result);
            } else {
              await Gal.putImage(result);
            }
            successCount++;
          } catch (e) {
            debugPrint('Galeriye kaydetme hatası: $e');
          }
        }

        // İlerleme güncelle (indirme bitti)
        onProgressUpdate((i + 1) / totalCount);
      }

      // Sonuç mesajı oluştur
      String message;
      bool success;

      if (successCount == totalCount) {
        message = '✓ $successCount medya indirildi!';
        success = true;
      } else if (successCount > 0) {
        message = '$successCount/$totalCount medya indirildi';
        success = true;
      } else {
        message = 'İndirme başarısız';
        success = false;
      }

      return DownloadResult(
        success: success,
        message: message,
        successCount: successCount,
        totalCount: totalCount,
      );
    } catch (e) {
      return DownloadResult(
        success: false,
        message: 'Hata: ${e.toString()}',
        successCount: 0,
        totalCount: medias.length,
      );
    } finally {
      onLoadingStateChange(false);
    }
  }
}

/// İndirme sonucu bilgilerini tutan sınıf
class DownloadResult {
  final bool success;
  final String message;
  final int successCount;
  final int totalCount;

  DownloadResult({
    required this.success,
    required this.message,
    required this.successCount,
    required this.totalCount,
  });

  Color get messageColor {
    if (success && successCount == totalCount) {
      return Colors.green;
    } else if (success && successCount > 0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
