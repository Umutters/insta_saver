String script = r'''
(function() {
  if (window.instaDownloaderV4) return;
  window.instaDownloaderV4 = true;

  window.globalMediaCache = new Map();

  function getCleanUrl(url) {
    if (!url) return '';
    return url.split('?')[0];
  }

  // URL'nin video thumbnail olup olmadığını kontrol et
  // Instagram thumbnail URL'leri genellikle şu pattern'leri içerir:
  function looksLikeThumbnail(url) {
    if (!url) return false;
    // Instagram video thumbnail signature'ları
    return url.includes('_n.jpg') || 
           url.includes('video_thumb') || 
           url.includes('thumbnail') ||
           // IG CDN'de video thumb için kullanılan pattern
           (url.includes('cdninstagram.com') && url.includes('.jpg') && url.includes('e35'));
  }

  function extractMediaFromContainer(container) {
    let medias = [];
    let ignoredBases = new Set();
    let ignoredUrls = new Set(); // Tam URL setini de tut

    // 1. ÖNCE VİDEOLARI TARA
    let videos = container.querySelectorAll('video');
    for (let vid of videos) {
      let poster = vid.getAttribute('poster') || vid.poster;
      if (poster) {
        ignoredBases.add(poster.split('?')[0]);
        ignoredUrls.add(poster);
      }
      
      // Video'nun parent container'ındaki TÜM img'leri de yakala
      // çünkü IG bazen poster'ı video'nun kardeş img'i olarak koyuyor
      let parentContainer = vid.closest('div[role]') || vid.parentElement?.parentElement;
      if (parentContainer) {
        let siblingImgs = parentContainer.querySelectorAll('img');
        siblingImgs.forEach(sImg => {
          if (sImg.src) {
            ignoredBases.add(sImg.src.split('?')[0]);
            ignoredUrls.add(sImg.src);
          }
        });
      }

      let url = vid.src;
      if (!url || url.startsWith('blob:')) {
        let source = vid.querySelector('source');
        if (source && source.src) url = source.src;
      }

      if (url && !url.startsWith('blob:')) {
        medias.push({ type: 'video', url: url, thumbnail: poster || '' });
      }
    }

    // 2. ŞİMDİ RESİMLERİ TARA
    let images = container.querySelectorAll('img');
    for (let img of images) {
      if (img.closest('header') || img.naturalWidth <= 150 || img.offsetWidth <= 150) continue;
      
      let imgUrl = img.src;
      if (!imgUrl || imgUrl.startsWith('data:')) continue;

      let imgBase = imgUrl.split('?')[0];

      // KONTROL 1: Base URL zaten video thumbnail olarak işaretlendi mi?
      if (ignoredBases.has(imgBase)) continue;
      
      // KONTROL 2: Tam URL daha önce işaretlendi mi?
      if (ignoredUrls.has(imgUrl)) continue;

      // KONTROL 3: Bu img'nin içinde veya yakınında video var mı?
      let hasVideoSibling = false;
      let checkParent = img.parentElement;
      for (let i = 0; i < 4; i++) { // 4 seviye yukarı bak
        if (!checkParent) break;
        if (checkParent.querySelector('video')) {
          hasVideoSibling = true;
          break;
        }
        checkParent = checkParent.parentElement;
      }
      if (hasVideoSibling) continue;

      // KONTROL 4: Play butonu var mı? (SVG tabanlı)
      let hasPlayButton = false;
      let parent = img.parentElement;
      if (parent) {
        let svg = parent.querySelector('svg[aria-label="Play video"], svg[aria-label="Videoyu oynat"], svg[aria-label="Play"]');
        if (!svg && parent.parentElement) {
          svg = parent.parentElement.querySelector('svg[aria-label="Play video"], svg[aria-label="Videoyu oynat"], svg[aria-label="Play"]');
        }
        if (svg) hasPlayButton = true;
      }
      if (hasPlayButton) continue;

      // KONTROL 5: URL'nin kendisi thumbnail'e benziyorsa ve videolar bulunduysa geç
      if (medias.length > 0 && looksLikeThumbnail(imgUrl)) continue;

      // KONTROL 6: img'nin role'ü veya aria-label'ı "presentation" veya video ile ilgiliyse geç
      let role = img.getAttribute('role');
      let ariaLabel = (img.getAttribute('aria-label') || '').toLowerCase();
      if (role === 'presentation' && medias.some(m => m.type === 'video')) continue;

      medias.push({ type: 'image', url: imgUrl, thumbnail: imgUrl });
    }
    return medias;
  }

  // ... (geri kalan kodun aynı kalacak)
''';
