/**
 * MultiEmbed JS Scraper Plugin for PlayTorrio
 */
var MultiEmbedScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'MultiEmbed',
  id: 'multiembed_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var type = params.type === 'tv' || params.type === 'series' ? 'tv' : 'movie';
    var tmdbId = params.tmdbId;
    var imdbId = params.imdbId || '';
    var season = params.season || 1;
    var episode = params.episode || 1;

    var results = [];
    if (!tmdbId && !imdbId) return results;

    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    var embedBase = 'https://www.2embed.cc';
    var embedPath = (type === 'tv')
      ? '/embedtv/' + tmdbId + '&s=' + season + '&e=' + episode
      : (imdbId && imdbId.startsWith('tt') ? '/embed/' + imdbId : '/embed/' + tmdbId);

    try {
      var res = await fetch(embedBase + embedPath, {
        method: 'GET',
        headers: {
          'User-Agent': ua,
          'Referer': 'https://www.2embed.cc/',
          'Accept': 'text/html'
        }
      });

      if (!res.ok) return results;
      var html = await res.text();

      var onclickMatches = html.match(/onclick=\x22go\('([^']+)'\)\x22/g) || [];
      var serverUrls = [];
      for (var i = 0; i < onclickMatches.length; i++) {
        var uM = onclickMatches[i].match(/go\('([^']+)'\)/);
        if (uM && uM[1] && uM[1].startsWith('http')) serverUrls.push(uM[1]);
      }

      var datasrcMatch = html.match(/data-src="([^"]+)"/);
      if (datasrcMatch && datasrcMatch[1] && datasrcMatch[1].startsWith('http')) {
        if (serverUrls.indexOf(datasrcMatch[1]) === -1) serverUrls.unshift(datasrcMatch[1]);
      }

      for (var s = 0; s < serverUrls.length; s++) {
        if (results.length >= 6) break;
        var sUrl = serverUrls[s];
        if (sUrl.indexOf('/xps') !== -1) {
          var pImdb = imdbId || '';
          var pTmdb = tmdbId ? String(tmdbId) : '';
          var xpsUrl = (type === 'tv')
            ? 'https://play.xpass.top/e/tv/' + pTmdb + '/' + season + '/' + episode + '?autostart=true'
            : 'https://play.xpass.top/e/movie/' + pImdb + '?autostart=true';

          try {
            var xpsRes = await fetch(xpsUrl, {
              method: 'GET',
              headers: { 'User-Agent': ua, 'Referer': 'https://streamsrcs.2embed.cc/' }
            });

            if (xpsRes.ok) {
              var xpsHtml = await xpsRes.text();
              var playlistMatch = xpsHtml.match(/"playlist"\s*:\s*"([^"]+)"/);
              var playlistPath = playlistMatch ? playlistMatch[1] : null;

              if (playlistPath) {
                var playlistUrl = playlistPath.startsWith('http')
                  ? playlistPath
                  : 'https://play.xpass.top' + (playlistPath.startsWith('/') ? '' : '/') + playlistPath;

                var plRes = await fetch(playlistUrl, {
                  method: 'GET',
                  headers: {
                    'User-Agent': ua,
                    'Referer': xpsUrl,
                    'Origin': 'https://play.xpass.top'
                  }
                });

                if (plRes.ok) {
                  var plJson = await plRes.json();
                  var playlists = plJson.playlist || [];
                  for (var p = 0; p < playlists.length; p++) {
                    var srcList = playlists[p].sources || [];
                    for (var k = 0; k < srcList.length; k++) {
                      var file = srcList[k].file;
                      if (file && file.startsWith('http') && file.indexOf('/error') === -1 && file.indexOf('.txt') === -1 && (file.indexOf('.m3u8') !== -1 || file.indexOf('.mp4') !== -1 || file.indexOf('/playlist/') !== -1)) {
                        var label = srcList[k].label || 'Auto';
                        results.push({
                          name: 'PlayTorrioHTTP',
                          addonName: 'PlayTorrioHTTP',
                          title: '2embed XPS · ' + label,
                          description: '2embed Multi-CDN Stream',
                          url: file,
                          headers: {
                            'User-Agent': ua,
                            'Referer': 'https://play.xpass.top/'
                          },
                          quality: label,
                          codec: 'h264',
                          isTorrent: false,
                          infoHash: null,
                          seeds: 0
                        });
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      console.log('MultiEmbedScraper error:', e);
    }
    return results;
  }
};
