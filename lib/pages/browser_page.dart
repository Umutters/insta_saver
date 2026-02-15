import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:insta_downloader/services/instagram_service.dart';
import 'package:insta_downloader/js_script.dart';

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
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.web, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Browser',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gez ve İndir',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Indicator
              if (_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_downloadProgress * 100).toInt()}% İndiriliyor...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

              // WebView
              Expanded(
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
                      onContentSizeChanged:
                          (webViewController, oldContentSize, newContentSize) {
                            // Sayfa içeriği değiştiğinde butonları tekrar enjekte et
                            _injectDownloadButtons(webViewController);
                          },
                      initialUrlRequest: URLRequest(
                        url: WebUri("https://www.instagram.com/"),
                      ),
                      initialSettings: settings,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;

                        // JavaScript handler ekle
                        _webViewController?.addJavaScriptHandler(
                          handlerName: 'downloadPost',
                          callback: (args) {
                            if (args.isNotEmpty) {
                              try {
                                final data = args[0].toString();
                                final jsonData = jsonDecode(data);
                                final postUrl = jsonData['url'] ?? '';
                                final medias =
                                    (jsonData['medias'] as List?)
                                        ?.map(
                                          (m) => Map<String, dynamic>.from(
                                            m as Map,
                                          ),
                                        )
                                        .toList() ??
                                    [];

                                if (medias.isNotEmpty) {
                                  _downloadFromUrl(postUrl, medias);
                                }
                              } catch (e) {
                                String postUrl = args[0].toString();
                                _downloadFromUrl(postUrl, []);
                              }
                            }
                          },
                        );
                      },
                      onLoadStop: (controller, url) async {
                        if (url != null) {
                          setState(() {
                            _currentUrl = url.toString();
                          });
                          // Immediate injection
                          await _injectDownloadButtons(controller);
                          // Second injection after a delay (for dynamically loaded content)
                          Future.delayed(
                            const Duration(milliseconds: 1500),
                            () {
                              _injectDownloadButtons(controller);
                            },
                          );
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          Future.delayed(const Duration(milliseconds: 800), () {
                            _injectDownloadButtons(controller);
                          });
                          // Another attempt after page is fully loaded
                          Future.delayed(const Duration(seconds: 2), () {
                            _injectDownloadButtons(controller);
                          });
                        }
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        // Filter out Permissions-Policy warnings from Instagram
                        final message = consoleMessage.message;
                        if (message.contains('Permissions-Policy header') ||
                            message.contains('Permissions policy violation')) {
                          return; // Suppress these specific warnings
                        }
                        // Log ALL other console messages for debugging
                        debugPrint(
                          '[WebView Console ${consoleMessage.messageLevel}] ${consoleMessage.message}',
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _injectDownloadButtons(InAppWebViewController controller) async {
    if (_webViewController == null) return;
    try {
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint("JS Injection Hatası: $e");
    }
  }

  Future<void> _downloadFromUrl(
    String postUrl,
    List<Map<String, dynamic>> medias,
  ) async {
    // 1. Güvenlik Kontrolü: Eğer medya listesi boşsa, kullanıcıya hata ver ve çık
    if (medias.isEmpty) {
      _showSnackBar(
        'Medya bağlantıları alınamadı. Lütfen sayfayı yenileyip tekrar deneyin.',
        Colors.red,
      );
      return;
    }

    // 2. Veri Hazırlama: Gelen listeyi manipüle edilebilir bir hale getir
    // selected: true diyerek BottomSheet açıldığında hepsini seçili başlatıyoruz
    final List<Map<String, dynamic>> preparedMedias = medias.map((m) {
      return {
        'type': m['type'] ?? 'image',
        'url': m['url'] ?? '',
        'thumbnail': m['thumbnail'] ?? m['url'] ?? '',
        'selected': true, // Başlangıçta hepsi seçili gelsin
      };
    }).toList();

    // 3. Geçersiz URL temizliği: Boş URL'leri listeden at
    preparedMedias.removeWhere((m) => m['url'].toString().isEmpty);

    if (preparedMedias.isEmpty) {
      _showSnackBar('İndirilebilir içerik bulunamadı.', Colors.orange);
      return;
    }

    // 4. Önizleme sayfasını aç
    await _showMediaPreviewSheet(postUrl, preparedMedias);
  }

  Future<void> _showMediaPreviewSheet(
    String postUrl,
    List<Map<String, dynamic>> medias,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MediaPreviewSheet(
        postUrl: postUrl,
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

    setState(() {
      _isLoading = true;
      _downloadProgress = 0.0;
    });

    try {
      int successCount = 0;
      int totalCount = medias.length;

      for (int i = 0; i < medias.length; i++) {
        final media = medias[i];

        setState(() {
          _downloadProgress = (i + 0.5) / totalCount;
        });

        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = media['type'] == 'video' ? 'mp4' : 'jpg';
        final savePath =
            '${directory.path}/instagram_${timestamp}_$i.$extension';

        final result = await _instagramService.downloadMedia(
          media['url'],
          savePath,
          (progress) {
            setState(() {
              _downloadProgress = (i + progress) / totalCount;
            });
          },
        );

        if (result != null) {
          try {
            if (media['type'] == 'video') {
              await Gal.putVideo(result);
            } else {
              await Gal.putImage(result);
            }
            successCount++;
          } catch (e) {
            print('Galeriye kaydetme hatası: $e');
          }
        }

        setState(() {
          _downloadProgress = (i + 1) / totalCount;
        });
      }

      if (successCount == totalCount) {
        _showSnackBar('✓ $successCount medya indirildi!', Colors.green);
      } else if (successCount > 0) {
        _showSnackBar(
          '$successCount/$totalCount medya indirildi',
          Colors.orange,
        );
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
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Medya önizleme BottomSheet
class _MediaPreviewSheet extends StatefulWidget {
  final String postUrl;
  final List<Map<String, dynamic>> medias;
  final Function(List<Map<String, dynamic>>) onDownload;

  const _MediaPreviewSheet({
    required this.postUrl,
    required this.medias,
    required this.onDownload,
  });

  @override
  State<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<_MediaPreviewSheet> {
  late List<Map<String, dynamic>> _medias;

  @override
  void initState() {
    super.initState();
    _medias = List.from(widget.medias);
  }

  void _toggleSelection(int index) {
    setState(() {
      _medias[index]['selected'] = !_medias[index]['selected'];
    });
  }

  void _toggleAll(bool select) {
    setState(() {
      for (var media in _medias) {
        media['selected'] = select;
      }
    });
  }

  int get _selectedCount => _medias.where((m) => m['selected'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFFD1D1D),
                  Color(0xFFFCAF45),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medya Seçin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'İndirmek istediğiniz medyaları seçin',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _toggleAll(true),
                          child: const Text(
                            'Tümü',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _toggleAll(false),
                          child: const Text(
                            'Hiçbiri',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _medias.isEmpty
                ? const Center(child: Text('Medya bulunamadı'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _medias.length,
                    itemBuilder: (context, index) {
                      final media = _medias[index];
                      final isSelected = media['selected'] ?? false;

                      return GestureDetector(
                        onTap: () => _toggleSelection(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF833AB4)
                                  : Colors.grey[300]!,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF833AB4,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  media['thumbnail'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        media['type'] == 'video'
                                            ? Icons.videocam
                                            : Icons.photo,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        media['type'] == 'video'
                                            ? 'VID'
                                            : 'IMG',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF833AB4)
                                        : Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_selectedCount medya seçildi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Toplam ${_medias.length} medya',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _selectedCount > 0
                        ? () {
                            final selected = _medias
                                .where((m) => m['selected'] == true)
                                .toList();
                            widget.onDownload(selected);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF833AB4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InAppWebViewSettings? settings = InAppWebViewSettings(
  javaScriptEnabled: true,
  useHybridComposition: true,
  allowsInlineMediaPlayback: true,
  mediaPlaybackRequiresUserGesture: false,
  domStorageEnabled: true, // Critical for login/auth
  databaseEnabled: true,
  allowFileAccess: true,
  allowContentAccess: true,
  allowFileAccessFromFileURLs: true,
  allowUniversalAccessFromFileURLs: true,
  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
  safeBrowsingEnabled: false,
  hardwareAcceleration: true,
);
