/**
 * VidSrc JS Scraper Plugin for PlayTorrio
 */
var VidSrcScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'VidSrc',
  id: 'vidsrc_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var type = params.type === 'tv' || params.type === 'series' ? 'tv' : 'movie';
    var tmdbId = params.tmdbId;
    var season = params.season || 1;
    var episode = params.episode || 1;
    var title = params.title || '';

    var results = [];
    if (!tmdbId) return results;

    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

    try {
      var isTv = (type === 'tv');
      var apiParams = [
        'type=' + (isTv ? 'tv' : 'movie'),
        'tmdb=' + tmdbId,
        'stream_urls='
      ];
      if (isTv) {
        apiParams.push('season=' + season);
        apiParams.push('episode=' + episode);
      }

      var apiUrl = 'https://data.vidsrcme.ru/api.php?' + apiParams.join('&');
      var res = await fetch(apiUrl, {
        method: 'GET',
        headers: {
          'User-Agent': ua,
          'Referer': 'https://cloudorchestranova.com/',
          'Accept': 'application/json'
        }
      });

      if (res.ok) {
        var json = await res.json();
        if (json.status_code === 200 && json.data && Array.isArray(json.data.stream_urls)) {
          var rawUrls = json.data.stream_urls;
          for (var i = 0; i < rawUrls.length; i++) {
            var url = String(rawUrls[i]).trim();
            if (!url || !url.startsWith('http')) continue;
            var isHls = url.indexOf('.m3u8') !== -1;

            results.push({
              name: 'PlayTorrioHTTP',
              addonName: 'PlayTorrioHTTP',
              title: rawUrls.length > 1 ? 'VidSrc ' + (i + 1) : 'VidSrc',
              description: isHls ? 'VidSrc Direct HLS Stream' : 'VidSrc Direct Stream Source',
              url: url,
              headers: {
                'User-Agent': ua,
                'Referer': 'https://cloudorchestranova.com/'
              },
              quality: 'HD',
              codec: 'h264',
              isTorrent: false,
              infoHash: null,
              seeds: 0
            });
          }
        }
      }

      // Embed Fallback
      if (results.length === 0) {
        var embedUrl = isTv
          ? 'https://vidsrc.me/embed/tv/' + tmdbId + '/' + season + '/' + episode
          : 'https://vidsrc.me/embed/movie/' + tmdbId;

        var embedRes = await fetch(embedUrl, {
          method: 'GET',
          headers: {
            'User-Agent': ua,
            'Referer': 'https://vidsrc.me/'
          }
        });

        if (embedRes.ok) {
          var html = await embedRes.text();
          var matches = html.match(/https?:\/\/[^"\x27\s]+\.m3u8[^"\x27\s]*/g) || [];
          for (var m = 0; m < matches.length; m++) {
            results.push({
              name: 'PlayTorrioHTTP',
              addonName: 'PlayTorrioHTTP',
              title: 'VidSrc Direct',
              description: 'VidSrc Direct HLS Stream',
              url: matches[m],
              headers: {
                'User-Agent': ua,
                'Referer': 'https://vidsrc.me/'
              },
              quality: 'HD',
              codec: 'h264',
              isTorrent: false,
              infoHash: null,
              seeds: 0
            });
          }
        }
      }
    } catch (e) {
      console.log('VidSrcScraper error:', e);
    }
    return results;
  }
};
