class VideoService {
  final Set<String> _capturedUrls = {};
  void checkAndCacheVideoUrl(String url) {
    if (url.isEmpty || url.startsWith('blob:')) return;

    // Video URL filtresi
    final isVideo =
        url.contains('.mp4') ||
        (url.contains('video') &&
            (url.contains('cdninstagram.com') || url.contains('fbcdn.net')));

    if (!isVideo) return;

    // Aynı URL'yi tekrar yakalamamak için kontrol
    if (_capturedUrls.contains(url)) return;

    _capturedUrls.add(url);
    print('🎯 Gerçek Video URL Yakalandı: $url');

    // Burada indirme işlemini tetikleyebilir veya
    // kullanıcıya "Video Hazır" bildirimi gönderebilirsin.
    print(url);
  }
}
