import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewSettings {
  static InAppWebViewSettings get defaultSettings => InAppWebViewSettings(
    javaScriptEnabled: true,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    domStorageEnabled: true,
    databaseEnabled: true,
    allowFileAccess: true,
    allowContentAccess: true,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    safeBrowsingEnabled: false,
    hardwareAcceleration: true,
    useShouldInterceptRequest: true,
  );
}
