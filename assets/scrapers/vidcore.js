/**
 * VidCore JS Scraper Plugin for PlayTorrio
 */
var VidCoreScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'VidCore',
  id: 'vidcore_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var type = params.type === 'tv' || params.type === 'series' ? 'tv' : 'movie';
    var tmdbId = params.tmdbId;
    var season = params.season || 1;
    var episode = params.episode || 1;

    var results = [];
    if (!tmdbId) return results;

    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    var bases = ['https://vidcore.net', 'https://www.vidcore.org', 'https://vidcore.org'];

    var qParams = [
      'id=' + tmdbId,
      'type=' + (type === 'tv' ? 'tv' : 'movie')
    ];
    if (type === 'tv') {
      qParams.push('season=' + season);
      qParams.push('episode=' + episode);
    }
    var qString = qParams.join('&');

    try {
      for (var b = 0; b < bases.length; b++) {
        if (results.length >= 6) break;
        var base = bases[b];
        var apiUrl = base + '/api/sources?' + qString;

        try {
          var res = await fetch(apiUrl, {
            method: 'GET',
            headers: {
              'User-Agent': ua,
              'Referer': base + '/embed/movie/' + tmdbId,
              'Origin': base,
              'Accept': 'application/json'
            }
          });

          if (res.ok) {
            var data = await res.json();
            var outerSources = data.sources || [];
            for (var i = 0; i < outerSources.length; i++) {
              var o = outerSources[i];
              var label = o.label || o.provider || o.server || 'VidCore';
              var inners = (o.data && o.data.sources) ? o.data.sources : (o.sources ? o.sources : [o]);

              for (var j = 0; j < inners.length; j++) {
                var s = inners[j];
                var streamUrl = s.url || s.file;
                if (!streamUrl || !streamUrl.startsWith('http')) continue;
                var q = s.quality || o.quality || 'Auto';

                results.push({
                  name: 'PlayTorrioHTTP',
                  addonName: 'PlayTorrioHTTP',
                  title: 'VidCore ' + label + ' · ' + q,
                  description: 'VidCore Direct HLS Stream',
                  url: streamUrl,
                  headers: {
                    'User-Agent': ua,
                    'Referer': base + '/'
                  },
                  quality: q,
                  codec: 'h264',
                  isTorrent: false,
                  infoHash: null,
                  seeds: 0
                });
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      console.log('VidCoreScraper error:', e);
    }
    return results;
  }
};
