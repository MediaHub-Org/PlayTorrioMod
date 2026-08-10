/**
 * FlyStream JS Scraper Plugin for PlayTorrio
 */
var FlyStreamScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'FlyStream',
  id: 'flystream_v1',
  version: '1.0.3',

  scrape: async function (params) {
    var type = params.type === 'tv' || params.type === 'series' ? 'tv' : 'movie';
    var title = params.title || '';
    var year = params.year ? String(params.year) : '';
    var tmdbId = params.tmdbId ? String(params.tmdbId) : '';
    var imdbId = params.imdbId || '';
    var season = params.season ? String(params.season) : '1';
    var episode = params.episode ? String(params.episode) : '1';

    var viewerId = 'playtorrio_' + Math.random().toString(36).substring(2, 10);
    var queryParams = [
      'type=' + encodeURIComponent(type),
      'viewerId=' + encodeURIComponent(viewerId),
      'title=' + encodeURIComponent(title)
    ];

    if (tmdbId) queryParams.push('tmdbId=' + encodeURIComponent(tmdbId));
    if (imdbId) queryParams.push('imdb=' + encodeURIComponent(imdbId));
    if (year) queryParams.push('year=' + encodeURIComponent(year));
    if (type === 'tv') {
      queryParams.push('season=' + encodeURIComponent(season));
      queryParams.push('episode=' + encodeURIComponent(episode));
    }

    var apiUrl = 'https://flystream.net/api/streams?' + queryParams.join('&');
    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    var headers = {
      'User-Agent': ua,
      'Referer': 'https://flystream.net/',
      'Accept': 'application/json'
    };

    var results = [];
    try {
      var res = await fetch(apiUrl, { method: 'GET', headers: headers });
      if (!res.ok) return results;
      var data = await res.json();
      var streams = data.streams || [];

      for (var i = 0; i < streams.length; i++) {
        var s = streams[i];
        var rawUrl = s.url || '';
        if (!rawUrl) continue;

        var playUrl = rawUrl.startsWith('/') ? 'https://flystream.net' + rawUrl : rawUrl;
        var directM3u8 = playUrl;

        // Resolve 302 redirect link to direct media.flystream.net index.m3u8 URL
        if (playUrl.indexOf('/play/') !== -1) {
          try {
            var redRes = await fetch(playUrl, {
              method: 'GET',
              headers: {
                'User-Agent': ua,
                'Referer': 'https://flystream.net/'
              }
            });
            if (redRes.url && redRes.url.indexOf('.m3u8') !== -1) {
              directM3u8 = redRes.url;
            }
          } catch (_) {}
        }

        var quality = s.quality || 'Auto';
        var codec = s.videoCodec ? s.videoCodec.toUpperCase() : '';
        var size = s.size || '';
        var name = s.name || s.title || title;

        var descParts = [];
        if (quality) descParts.push(quality);
        if (codec) descParts.push(codec);
        if (size) descParts.push(size);

        results.push({
          name: 'PlayTorrioHTTP',
          addonName: 'PlayTorrioHTTP',
          title: 'FlyStream ' + name,
          description: descParts.length > 0 ? 'FlyStream ' + descParts.join(' · ') : 'FlyStream Direct HLS Stream',
          url: directM3u8,
          headers: {
            'User-Agent': ua,
            'Referer': 'https://flystream.net/'
          },
          quality: quality,
          codec: codec,
          isTorrent: false,
          infoHash: null,
          seeds: 0
        });
      }
    } catch (e) {
      console.log('FlyStreamScraper JS error:', e);
    }
    return results;
  }
};
