class MediaUtils {
  /// Medya listesini indirme için hazırlar
  static List<Map<String, dynamic>> prepareMediasForDownload(
    List<Map<String, dynamic>> medias,
  ) {
    final preparedMedias = medias.map((m) {
      return {
        'type': m['type'] ?? 'image',
        'url': m['url'] ?? '',
        'thumbnail': m['thumbnail'] ?? m['url'] ?? '',
        'selected': true,
      };
    }).toList();

    // Geçersiz URL'leri temizle
    preparedMedias.removeWhere((m) => m['url'].toString().isEmpty);

    return preparedMedias;
  }

  /// Dosya uzantısını medya tipine göre belirler
  static String getFileExtension(String mediaType) {
    return mediaType == 'video' ? 'mp4' : 'jpg';
  }

  /// Dosya adı oluşturur
  static String generateFileName(int timestamp, int index, String extension) {
    return 'instagram_${timestamp}_$index.$extension';
  }
}
