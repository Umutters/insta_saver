import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:insta_downloader/services/instagram_service.dart';
import 'package:insta_downloader/services/media_downloader.dart';
import 'package:insta_downloader/js_script.dart';
import 'package:insta_downloader/config/webview_settings.dart';
import 'package:insta_downloader/handlers/webview_handler.dart';
import 'package:insta_downloader/utils/media_utils.dart';
import 'package:insta_downloader/widgets/browser_progress_indicator.dart';
import 'package:insta_downloader/widgets/header.dart';
import 'package:insta_downloader/widgets/media_preview_sheet.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _webViewController;
  String _currentUrl = '';
  bool _isLoading = false;
  double _downloadProgress = 0.0;
  final InstagramService _instagramService = InstagramService();
  late final MediaDownloader _mediaDownloader;

  // JS src-hook ile yakalanan gerçek video CDN URL'leri
  // Key: post shortcode, Value: CDN URL listesi
  final Map<String, List<String>> _interceptedVideoUrls = {};

  /// Instagram URL'sinden post shortcode'unu çıkarır
  String? _extractPostShortcode(String url) {
    final regex = RegExp(r'instagram\.com/(?:p|reel|tv)/([a-zA-Z0-9_-]+)');
    return regex.firstMatch(url)?.group(1);
  }

  /// JS'den gelen video URL'sini cache'e ekler
  void _cacheVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty || videoUrl.startsWith('blob:')) return;
    final key = _extractPostShortcode(_currentUrl) ?? _currentUrl;
    _interceptedVideoUrls.putIfAbsent(key, () => []);
    if (!_interceptedVideoUrls[key]!.contains(videoUrl)) {
      _interceptedVideoUrls[key]!.add(videoUrl);
      debugPrint('📹 JS video yakalandı [$key]: $videoUrl');
    }
  }

  @override
  void initState() {
    super.initState();
    _mediaDownloader = MediaDownloader(
      instagramService: _instagramService,
      onProgressUpdate: (progress) {
        setState(() => _downloadProgress = progress);
      },
      onLoadingStateChange: (isLoading) {
        setState(() {
          _isLoading = isLoading;
          if (!isLoading) _downloadProgress = 0.0;
        });
      },
    );
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: "Tarayıcı",
                subtitle: "Arama Yaparak indirin",
              ),
              if (_isLoading)
                BrowserProgressIndicator(progress: _downloadProgress),
              _buildWebView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri("https://www.instagram.com/"),
            ),
            initialSettings: WebViewSettings.defaultSettings,
            onWebViewCreated: _onWebViewCreated,
            onLoadStop: _onLoadStop,
            onProgressChanged: _onProgressChanged,
            onConsoleMessage: _onConsoleMessage,
            onContentSizeChanged: (controller, oldSize, newSize) {
              _injectDownloadButtons(controller);
            },
            shouldInterceptRequest: (controller, request) async {
              final url = request.url.toString();
              // fbcdn.net veya cdninstagram.com'dan gelen .mp4 URL'lerini yakala
              if (url.contains('.mp4') &&
                  (url.contains('fbcdn.net') ||
                      url.contains('cdninstagram.com') ||
                      url.contains('instagram.f'))) {
                _cacheVideoUrl(url);
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  // WebView Callbacks
  void _onWebViewCreated(InAppWebViewController controller) {
    _webViewController = controller;
    _setupJavaScriptHandler();
  }

  void _setupJavaScriptHandler() {
    // Video URL yakalama handler'i — JS src hook'undan geliyor
    _webViewController?.addJavaScriptHandler(
      handlerName: 'videoUrlFound',
      callback: (args) {
        if (args.isEmpty) return;
        _cacheVideoUrl(args[0].toString());
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'downloadPost',
      callback: (args) {
        if (args.isEmpty) return;

        try {
          final rawData = args[0];
          debugPrint('Handler çağrıldı, veri tipi: ${rawData.runtimeType}');

          final jsonData = WebViewHandlers.parseDownloadData(rawData);
          if (jsonData == null) {
            _showSnackBar('Hatalı veri formatı', Colors.red);
            return;
          }

          var medias = WebViewHandlers.parseMediaList(jsonData['medias']);
          debugPrint('Bulunan medya sayısı: ${medias.length}');

          // JS'den gelen boş/blob video URL'lerini intercepted CDN URL'leriyle doldur
          final postUrl = (jsonData['url'] as String?) ?? _currentUrl;
          final shortcode = _extractPostShortcode(postUrl) ?? postUrl;
          final cachedVideos = _interceptedVideoUrls[shortcode] ?? [];
          debugPrint(
            '📦 Cache\'te ${cachedVideos.length} video URL var [$shortcode]',
          );

          int videoIndex = 0;
          medias = medias.map((media) {
            if (media['type'] == 'video') {
              final currentUrl = (media['url'] as String?) ?? '';
              if ((currentUrl.isEmpty || currentUrl.startsWith('blob:')) &&
                  videoIndex < cachedVideos.length) {
                final enriched = Map<String, dynamic>.from(media);
                enriched['url'] = cachedVideos[videoIndex++];
                return enriched;
              }
            }
            return media;
          }).toList();

          if (medias.isNotEmpty) {
            _handleDownloadRequest(medias);
          } else {
            _showSnackBar('Medya bulunamadı', Colors.orange);
          }
        } catch (e) {
          debugPrint('Handler hatası: $e');
          _showSnackBar('Medya işlenirken hata oluştu: $e', Colors.red);
        }
      },
    );
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (url != null) {
      setState(() => _currentUrl = url.toString());

      await _injectDownloadButtons(controller);

      // Dinamik içerik için gecikmeli enjeksiyonlar
      Future.delayed(const Duration(milliseconds: 1500), () {
        _injectDownloadButtons(controller);
      });
    }
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (progress == 100) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _injectDownloadButtons(controller);
      });
      Future.delayed(const Duration(seconds: 2), () {
        _injectDownloadButtons(controller);
      });
    }
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    final message = consoleMessage.message;

    // Instagram'ın Permissions-Policy uyarılarını filtrele
    if (message.contains('Permissions-Policy header') ||
        message.contains('Permissions policy violation')) {
      return;
    }

    debugPrint('[WebView Console ${consoleMessage.messageLevel}] $message');
  }

  // JavaScript Injection
  Future<void> _injectDownloadButtons(InAppWebViewController controller) async {
    if (_webViewController == null) return;
    try {
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint("JS Injection Hatası: $e");
    }
  }

  // Download Handlers
  void _handleDownloadRequest(List<Map<String, dynamic>> medias) {
    if (medias.isEmpty) {
      _showSnackBar(
        'Medya bağlantıları alınamadı. Lütfen sayfayı yenileyip tekrar deneyin.',
        Colors.red,
      );
      return;
    }

    final preparedMedias = MediaUtils.prepareMediasForDownload(medias);

    if (preparedMedias.isEmpty) {
      _showSnackBar('İndirilebilir içerik bulunamadı.', Colors.orange);
      return;
    }

    _showMediaPreviewSheet(preparedMedias);
  }

  Future<void> _showMediaPreviewSheet(List<Map<String, dynamic>> medias) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaPreviewSheet(
        postUrl: _currentUrl,
        medias: medias,
        onDownload: (selectedMedias) async {
          Navigator.pop(context);
          await _downloadSelectedMedias(selectedMedias);
        },
      ),
    );
  }

  Future<void> _downloadSelectedMedias(
    List<Map<String, dynamic>> medias,
  ) async {
    if (medias.isEmpty) {
      _showSnackBar('Hiç medya seçilmedi', Colors.orange);
      return;
    }

    final result = await _mediaDownloader.downloadMedias(medias);
    _showSnackBar(result.message, result.messageColor);
  }

  // UI Helpers
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
