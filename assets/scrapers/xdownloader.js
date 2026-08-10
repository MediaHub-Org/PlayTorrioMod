/**
 * X-Downloader JS Scraper Plugin for PlayTorrio
 */
var XDownloaderScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'XDownloader',
  id: 'xdownloader_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var title = params.title || '';
    var type = (params.type === 'series' || params.type === 'tv') ? 'tv' : 'movie';
    var results = [];

    var baseUrl = 'https://www.films365.org';
    var headers = {
      'Authorization': 'Bearer 79a02956be35835728a044b11e2ae793149d45fb2c89cb6d029ec01aac19bfdb',
      'Content-Type': 'application/json',
      'User-Agent': 'MovieDownloader/1.0'
    };

    try {
      var searchRes = await fetch(baseUrl + '/api/mobile/search', {
        method: 'POST',
        headers: headers,
        body: JSON.stringify({ query: title })
      });

      if (!searchRes.ok) return results;
      var searchJson = await searchRes.json();
      var rObj = searchJson.results || {};
      var items = rObj.all || rObj.movies || rObj.tvs || [];
      if (items.length === 0) return results;

      var matchedItem = items[0];
      var itemId = matchedItem.id || matchedItem.tmdbId;
      if (!itemId) return results;

      var detailsRes = await fetch(baseUrl + '/api/mobile/details?id=' + itemId + '&type=' + type, {
        method: 'GET',
        headers: headers
      });

      if (!detailsRes.ok) return results;
      var detailsJson = await detailsRes.json();
      var data = detailsJson.data || {};
      var streamUrl = data.downloadUrl || data.videoUrl;

      if (streamUrl && streamUrl.startsWith('http')) {
        results.push({
          name: 'PlayTorrioHTTP',
          addonName: 'PlayTorrioHTTP',
          title: 'X-Downloader ' + (matchedItem.title || title),
          description: 'X-Downloader Direct MP4 Stream',
          url: streamUrl,
          headers: { 'User-Agent': 'MovieDownloader/1.0' },
          quality: '1080p',
          codec: 'h264',
          isTorrent: false,
          infoHash: null,
          seeds: 0
        });
      }
    } catch (e) {
      console.log('XDownloaderScraper JS error:', e);
    }
    return results;
  }
};
