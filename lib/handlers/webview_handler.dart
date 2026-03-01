import 'dart:convert';
import 'package:flutter/material.dart';

/// WebView JavaScript handler için callback fonksiyonu
class WebViewHandlers {
  /// JavaScript'ten gelen download request'ini işler
  static Map<String, dynamic>? parseDownloadData(dynamic rawData) {
    try {
      if (rawData is String) {
        return jsonDecode(rawData) as Map<String, dynamic>;
      } else if (rawData is Map) {
        return Map<String, dynamic>.from(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('parseDownloadData hatası: $e');
      return null;
    }
  }

  /// Medya listesini parse eder
  static List<Map<String, dynamic>> parseMediaList(dynamic mediasData) {
    try {
      if (mediasData is List) {
        return mediasData
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('parseMediaList hatası: $e');
      return [];
    }
  }
}
