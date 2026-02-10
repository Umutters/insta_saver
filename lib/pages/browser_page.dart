import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:insta_downloader/services/instagram_service.dart';

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
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri("https://www.instagram.com/"),
                      ),
                      initialSettings: InAppWebViewSettings(
                        userAgent:
                            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                        javaScriptEnabled: true,
                        useHybridComposition: true,
                        allowsInlineMediaPlayback: true,
                        mediaPlaybackRequiresUserGesture: false,
                        domStorageEnabled: true, // Critical for login/auth
                        databaseEnabled: true,
                        allowFileAccess: true,
                        allowContentAccess: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;

                        // JavaScript handler ekle
                        controller.addJavaScriptHandler(
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
                          await _injectDownloadButtons(controller);
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          Future.delayed(const Duration(seconds: 1), () {
                            _injectDownloadButtons(controller);
                          });
                        }
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
    await controller.evaluateJavascript(
      source: '''
      (function() {
        // Prevent multiple injections
        if (window.instaDownloaderInjected) return;
        window.instaDownloaderInjected = true;
        console.log("InstaDownloader: Injected successfully");
        
        // Mark processed articles to avoid re-processing
        const processedArticles = new WeakSet();

        // Helper: Extract shortcode from URL
        function getShortcode(url) {
            const match = url.match(/\/p\/([a-zA-Z0-9_-]+)/) || 
                          url.match(/\/reel\/([a-zA-Z0-9_-]+)/) ||
                          url.match(/\/tv\/([a-zA-Z0-9_-]+)/);
            return match ? match[1] : null;
        }

        // Helper: Fetch post data from Instagram Internal API
        async function fetchPostData(shortcode) {
           try {
                // Correct way to construct URL without confusing Dart/JS interpolation
                const url = "https://www.instagram.com/p/" + shortcode + "/?__a=1&__d=dis";
                const response = await fetch(url);
                const json = await response.json();
                
                const items = json.items || (json.graphql && json.graphql.shortcode_media ? [json.graphql.shortcode_media] : []);
                
                if (!items || items.length === 0) return null;
                
                const item = items[0];
                return item;
           } catch (e) {
               console.error("Fetch failed", e);
               return null;
           }
        }

        function parseMediaFromItem(item) {
             const medias = [];
             
             if (item.carousel_media) {
                 item.carousel_media.forEach((media, index) => {
                     if (media.video_versions && media.video_versions.length > 0) {
                         medias.push({
                             type: 'video',
                             url: media.video_versions[0].url,
                             thumbnail: media.image_versions2.candidates[0].url,
                             id: media.id,
                             index: index
                         });
                     } else {
                         const candidates = media.image_versions2.candidates;
                         const best = candidates.sort((a,b) => b.width - a.width)[0];
                         medias.push({
                             type: 'image',
                             url: best.url,
                             thumbnail: best.url,
                             id: media.id,
                             index: index
                         });
                     }
                 });
             } else {
                 if (item.video_versions && item.video_versions.length > 0) {
                      medias.push({
                             type: 'video',
                             url: item.video_versions[0].url,
                             thumbnail: item.image_versions2.candidates[0].url,
                             id: item.id,
                             index: 0
                         });
                 } else {
                      const candidates = item.image_versions2.candidates;
                      const best = candidates.sort((a,b) => b.width - a.width)[0];
                      medias.push({
                             type: 'image',
                             url: best.url,
                             thumbnail: best.url,
                             id: item.id,
                             index: 0
                         });
                 }
             }
             return medias;
        }

        function addStoryDownloadBtn() {
          const existingStoryBtn = document.getElementById('story-download-btn');
          
          if (window.location.href.includes('/stories/')) {
            if (existingStoryBtn) return;
            
            const storyBtn = document.createElement('div');
            storyBtn.id = 'story-download-btn';
            storyBtn.innerHTML = '⬇️ Story';
            storyBtn.style.cssText = `
              position: fixed;
              top: 80px;
              right: 20px;
              z-index: 999999;
              background: linear-gradient(135deg, #833AB4, #FD1D1D);
              color: white;
              border: none;
              border-radius: 20px;
              padding: 10px 16px;
              font-size: 14px;
              font-weight: bold;
              cursor: pointer;
              box-shadow: 0 4px 15px rgba(131, 58, 180, 0.6);
            `;
            
            storyBtn.onclick = function() {
              // ... existing story download logic ...
              // For brevity, using simple scraper here or could use API if needed
               const medias = [];
               const videos = document.querySelectorAll('video[src]');
               videos.forEach((video) => {
                   if (video.src && video.src.length > 20) {
                        medias.push({type: 'video', url: video.src, thumbnail: video.poster || video.src, index: 0});
                   }
               });
               if (medias.length === 0) {
                   const images = document.querySelectorAll('img[src*="instagram"]');
                   images.forEach((img) => {
                       if (img.naturalWidth > 400) {
                            medias.push({type: 'image', url: img.src, thumbnail: img.src, index: 0});
                       }
                   });
               }
               
               if (window.flutter_inappwebview && medias.length > 0) {
                    window.flutter_inappwebview.callHandler('downloadPost', JSON.stringify({
                      url: window.location.href,
                      medias: medias
                    }));
               }
            };
            
            document.body.appendChild(storyBtn);
          } else {
            if (existingStoryBtn) existingStoryBtn.remove();
          }
        }
        
        function addPostDownloadButtons() {
          // Select articles more broadly
          const articles = document.querySelectorAll('article, div[role="article"]');
          console.log("Found articles: " + articles.length);
          
          articles.forEach((article) => {
            if (article.querySelector('.insta-download-btn')) return;
            
            // DON'T mark as processed yet until we confirm it has a link
            // if (processedArticles.has(article)) return; 
            
            const timeLink = article.querySelector('a[href*="/p/"], a[href*="/reel/"]');
            if (!timeLink) return; // Not ready yet
            
            processedArticles.add(article); // NOW we can mark it
            
            const postUrl = 'https://www.instagram.com' + timeLink.getAttribute('href');
            const shortcode = getShortcode(postUrl);
            
            if (!shortcode) return;

            const downloadBtn = document.createElement('div');
            downloadBtn.className = 'insta-download-btn';
            downloadBtn.innerHTML = '⬇️';
            
            downloadBtn.style.cssText = `
                position: absolute;
                top: 10px;
                right: 10px;
                z-index: 9999;
                background: rgba(0, 0, 0, 0.7);
                color: white;
                border: 2px solid white;
                border-radius: 50%;
                width: 46px;
                height: 46px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 20px;
                cursor: pointer;
                box-shadow: 0 2px 10px rgba(0, 0, 0, 0.5);
              `;

            downloadBtn.onclick = async function(e) {
                e.stopPropagation();
                e.preventDefault();
                
                this.innerHTML = '⏳';
                const item = await fetchPostData(shortcode);
                
                if (item) {
                    const medias = parseMediaFromItem(item);
                    if (window.flutter_inappwebview) {
                        window.flutter_inappwebview.callHandler('downloadPost', JSON.stringify({
                            url: postUrl,
                            medias: medias
                        }));
                    }
                    this.style.background = 'rgba(76, 175, 80, 0.9)';
                    this.innerHTML = '✓';
                } else {
                    this.innerHTML = '⚠️';
                    // Fallback to empty to trigger feedback
                     if (window.flutter_inappwebview) {
                        window.flutter_inappwebview.callHandler('downloadPost', JSON.stringify({url: postUrl, medias: []}));
                    }
                }
                
                setTimeout(() => {
                    this.style.background = 'rgba(0, 0, 0, 0.7)';
                    this.innerHTML = '⬇️';
                }, 2000);
            };
            
            // Try to find header to append to, or just relative to article
            const header = article.querySelector('header');
            if(header) {
                 header.style.position = 'relative'; 
                 header.appendChild(downloadBtn);
            } else {
                 article.style.position = 'relative';
                 article.appendChild(downloadBtn);
            }
          });
        }
        
        // Initial run
        addStoryDownloadBtn();
        addPostDownloadButtons();
        
        // Use MutationObserver for DOM changes
        const observer = new MutationObserver(() => {
          addStoryDownloadBtn();
          addPostDownloadButtons();
        });
        
        observer.observe(document.body, {childList: true, subtree: true});
        
        // Polling interval (Safety net)
        setInterval(() => {
            addStoryDownloadBtn();
            addPostDownloadButtons();
        }, 1500); 
        
      })();
    ''',
    );
  }

  Future<void> _downloadFromUrl(
    String postUrl,
    List<Map<String, dynamic>> medias,
  ) async {
    if (medias.isEmpty) {
      medias = [
        {
          'type': 'image',
          'url': 'https://picsum.photos/1080/1080?random=1',
          'thumbnail': 'https://picsum.photos/300/300?random=1',
          'selected': true,
        },
      ];
    } else {
      for (var media in medias) {
        media['selected'] = true;
      }
    }

    await _showMediaPreviewSheet(postUrl, medias);
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
                                        if (loadingProgress == null)
                                          return child;
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
