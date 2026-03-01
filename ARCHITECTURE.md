# Instagram Downloader - Kod Yapısı

## 📁 Proje Yapısı

```
lib/
├── config/
│   └── webview_settings.dart      # WebView ayarları
├── handlers/
│   └── webview_handler.dart       # WebView callback handler'ları
├── services/
│   ├── instagram_service.dart      # Instagram API servisi
│   └── media_downloader.dart       # Medya indirme servisi
├── utils/
│   └── media_utils.dart            # Medya işleme yardımcı fonksiyonları
├── widgets/
│   ├── browser_header.dart         # Browser header widget'ı
│   ├── browser_progress_indicator.dart  # İndirme progress bar'ı
│   └── media_preview_sheet.dart    # Medya önizleme bottom sheet
├── pages/
│   ├── browser_page.dart           # Ana browser sayfası
│   ├── downloads_page.dart         # İndirilenler sayfası
│   └── ...
├── js_script.dart                  # JavaScript injection kodları
├── main.dart                       # Ana uygulama dosyası
└── main_screen.dart                # Ana navigation ekranı
```

## 🎯 Modül Açıklamaları

### Config
- **webview_settings.dart**: WebView için gerekli tüm ayarları içerir

### Handlers
- **webview_handler.dart**: JavaScript'ten gelen verileri parse eder

### Services
- **instagram_service.dart**: Instagram'dan medya indirme işlemlerini yönetir
- **media_downloader.dart**: İndirme sürecini koordine eder, progress tracking sağlar

### Utils
- **media_utils.dart**: Medya dosyalarıyla ilgili yardımcı fonksiyonlar

### Widgets
- **browser_header.dart**: Browser sayfası başlığı
- **browser_progress_indicator.dart**: İndirme ilerleme göstergesi
- **media_preview_sheet.dart**: Medya seçim ve önizleme ekranı

## 🔄 İş Akışı

1. **BrowserPage** WebView'ı yükler
2. JavaScript injection ile Instagram sayfasına indirme butonu eklenir
3. Kullanıcı butona tıkladığında **WebViewHandlers** veriyi parse eder
4. **MediaUtils** medya listesini hazırlar
5. **MediaPreviewSheet** kullanıcıya seçim imkanı sunar
6. **MediaDownloader** seçili medyaları indirir
7. Progress **BrowserProgressIndicator** ile gösterilir

## 🛠️ Kullanılan Teknolojiler

- Flutter 3.x
- flutter_inappwebview
- gal (galeri erişimi)
- dio (HTTP istekleri)
- path_provider

## 📝 Kod Kalitesi

- ✅ Modüler yapı
- ✅ Tek sorumluluk prensibi
- ✅ Yeniden kullanılabilir widget'lar
- ✅ Temiz kod yaklaşımı
- ✅ Error handling
