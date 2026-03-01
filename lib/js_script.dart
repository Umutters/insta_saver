String script = r'''
(function() {
  if (window.instaDownloaderV5) return;
  window.instaDownloaderV5 = true;

  window.globalMediaCache = new Map();

  // ---- VIDEO SRC HOOK ----
  // video.src set edildiği anda (blob'a dönüşmeden önce) gerçek CDN URL'sini yakala
  if (!window._videoSrcHooked) {
    window._videoSrcHooked = true;
    const srcDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
    if (srcDesc && srcDesc.set) {
      Object.defineProperty(HTMLMediaElement.prototype, 'src', {
        set: function(url) {
          if (url && !url.startsWith('blob:') && !url.startsWith('data:') &&
              (url.includes('cdninstagram') || url.includes('fbcdn') || url.includes('.mp4'))) {
            console.log('VIDEO_SRC_HOOK: ' + url);
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('videoUrlFound', url);
            }
          }
          srcDesc.set.call(this, url);
        },
        get: srcDesc.get,
        configurable: true,
      });
    }

    // currentSrc üzerinden de dinle (bazı durumlarda src setter tetiklenmez)
    document.addEventListener('loadstart', function(e) {
      if (e.target && e.target.tagName === 'VIDEO') {
        const url = e.target.currentSrc || e.target.src || '';
        if (url && !url.startsWith('blob:') && !url.startsWith('data:') &&
            (url.includes('cdninstagram') || url.includes('fbcdn') || url.includes('.mp4'))) {
          console.log('VIDEO_LOADSTART: ' + url);
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('videoUrlFound', url);
          }
        }
      }
    }, true);
  }
  // ---- VIDEO SRC HOOK END ----

  function getCleanUrl(url) {
    if (!url) return '';
    return url.split('?')[0];
  }

  function extractMediaFromContainer(container) {
    let medias = [];
    
    // YENİ MANTIK: Fiziksel ekran koordinatlarını hafızaya alıyoruz
    let videoRects = [];
    let playBtnRects = [];

    // 1. Ekrandaki tüm videoların sınırlarını (koordinatlarını) bul
    let videos = container.querySelectorAll('video');
    for (let vid of videos) {
      let rect = vid.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) videoRects.push(rect); // Ekranda görünüyorsa kaydet

      let url = vid.src;
      if (!url || url.startsWith('blob:')) {
        let source = vid.querySelector('source');
        if (source && source.src) url = source.src;
      }
      if (url && !url.startsWith('blob:')) {
        medias.push({ type: 'video', url: url, thumbnail: vid.getAttribute('poster') || '' });
      }
    }

    // 2. Ekrandaki tüm "Oynat (Play)" butonlarının koordinatlarını bul
    let svgs = container.querySelectorAll('svg[aria-label="Play video"], svg[aria-label="Videoyu oynat"], svg[aria-label="Play"]');
    for (let svg of svgs) {
      let rect = svg.getBoundingClientRect();
      if (rect.width > 0) playBtnRects.push(rect);
    }

    // 3. ŞİMDİ RESİMLERİ TARA VE KOORDİNAT ÇAKIŞMASINA BAK
    let images = container.querySelectorAll('img');
    for (let img of images) {
      // Çok küçük resimleri (profil fotoları vb.) atla
      if (img.closest('header') || img.naturalWidth <= 150 || img.offsetWidth <= 150) continue;

      let rect = img.getBoundingClientRect();
      let isVideoCover = false;

      // KURAL 1: Bu resim, az önce bulduğumuz bir video ile ekranda aynı yeri mi kaplıyor? (50 piksel hata payı)
      for (let vRect of videoRects) {
        if (Math.abs(rect.top - vRect.top) < 50 && Math.abs(rect.left - vRect.left) < 50) {
          isVideoCover = true; 
          break;
        }
      }

      // KURAL 2: Oynat (Play) butonu, fiziksel olarak bu resmin sınırları içinde mi duruyor?
      if (!isVideoCover) {
        for (let pRect of playBtnRects) {
          // Eğer play butonu bu resmin x, y koordinatlarının içindeyse:
          if (pRect.top >= rect.top && pRect.bottom <= rect.bottom && pRect.left >= rect.left && pRect.right <= rect.right) {
            isVideoCover = true; 
            break;
          }
        }
      }

      // Eğer koordinatlar çakışıyorsa, bu resim KESİNLİKLE bir video kapağıdır, listeye alma!
      if (isVideoCover) continue; 

      // Buraya kadar geldiyse bu %100 temiz, gerçek bir fotoğraftır.
      if (img.src && !img.src.startsWith('data:')) {
        medias.push({ type: 'image', url: img.src, thumbnail: img.src });
      }
    }
    
    return medias;
  }

  function updateCacheForArticle(article, postUrl) {
    if (!postUrl) return;
    let newlyFoundMedias = extractMediaFromContainer(article);
    if (!window.globalMediaCache.has(postUrl)) {
      window.globalMediaCache.set(postUrl, []);
    }
    let existingMedias = window.globalMediaCache.get(postUrl);
    newlyFoundMedias.forEach(newMedia => {
      if (!existingMedias.some(m => m.url === newMedia.url)) {
        existingMedias.push(newMedia);
      }
    });
    window.globalMediaCache.set(postUrl, existingMedias);
  }

  function injectFeedButton(article, postUrl) {
    if (article.querySelector('.insta-feed-btn')) return;
    const btn = document.createElement('div');
    btn.className = 'insta-download-btn insta-feed-btn';
    btn.innerHTML = '💾';
    
    if (window.getComputedStyle(article).position === 'static') {
      article.style.position = 'relative';
    }

    btn.style.cssText = `position:absolute; right:15px; top:15px; z-index:9999; background:white; border-radius:50%; width:45px; height:45px; display:flex; align-items:center; justify-content:center; cursor:pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.5); font-size:24px; border: 2px solid #FD1D1D;`;

    btn.onclick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      updateCacheForArticle(article, postUrl);
      let finalMedias = window.globalMediaCache.get(postUrl) || [];

      if (window.flutter_inappwebview && finalMedias.length > 0) {
        window.flutter_inappwebview.callHandler('downloadPost', JSON.stringify({
          url: postUrl,
          medias: finalMedias
        }));
        btn.innerHTML = '✅';
        setTimeout(() => btn.innerHTML = '💾', 2000);
      } else {
        btn.innerHTML = '❌'; 
        setTimeout(() => btn.innerHTML = '💾', 2000);
      }
    };
    article.appendChild(btn);
  }

  function scanDOM() {
    let currentUrl = window.location.href;

    if (currentUrl.includes('/stories/')) {
      let existingBtn = document.getElementById('insta-story-btn');
      if (!existingBtn) {
        const btn = document.createElement('div');
        btn.id = 'insta-story-btn';
        btn.className = 'insta-download-btn';
        btn.innerHTML = '💾';
        
        btn.style.cssText = `position:fixed; right:20px; bottom:80px; z-index:2147483647; background:white; border-radius:50%; width:50px; height:50px; display:flex; align-items:center; justify-content:center; cursor:pointer; box-shadow: 0 4px 16px rgba(0,0,0,0.6); font-size:26px; border: 2px solid #FD1D1D;`;

        btn.onclick = (e) => {
          e.preventDefault();
          e.stopPropagation();
          let medias = extractMediaFromContainer(document);
          
          if (window.flutter_inappwebview && medias.length > 0) {
            window.flutter_inappwebview.callHandler('downloadPost', JSON.stringify({
              url: currentUrl,
              medias: medias
            }));
            btn.innerHTML = '✅';
            setTimeout(() => btn.innerHTML = '💾', 2000);
          } else {
            btn.innerHTML = '❌';
            setTimeout(() => btn.innerHTML = '💾', 2000);
          }
        };
        document.body.appendChild(btn);
      }
    } 
    else {
      let existingStoryBtn = document.getElementById('insta-story-btn');
      if (existingStoryBtn) existingStoryBtn.remove();

      let articles = document.querySelectorAll('article');
      articles.forEach(article => {
        let postUrl = currentUrl;
        let links = article.querySelectorAll('a[href*="/p/"], a[href*="/reel/"]');
        if (links.length > 0) {
          postUrl = "https://www.instagram.com" + getCleanUrl(links[0].getAttribute('href'));
        }
        updateCacheForArticle(article, postUrl);
        injectFeedButton(article, postUrl);
      });
    }
  }

  setInterval(scanDOM, 500);
})();
''';
