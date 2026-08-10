/**
 * TorrentGalaxy JS Scraper Plugin for PlayTorrio
 * 1:1 Port of TorrentGalaxyScraper
 */
var TorrentGalaxyScraper = {
  name: 'PlayTorrio',
  provider: 'TorrentGalaxy',
  id: 'torrent_galaxy_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var title = params.title || '';
    var year = params.year;
    var type = params.type;
    var season = params.season;
    var episode = params.episode;
    var results = [];

    var query = title.trim();
    if (type === 'movie' && year) {
      query += ' ' + year;
    } else if (type === 'tv' || type === 'series') {
      if (season) {
        var sStr = (season < 10 ? '0' : '') + season;
        query += ' s' + sStr;
      }
    }

    var searchUrl = 'https://torrentgalaxy.info/get-posts/keywords:' + encodeURIComponent(query);
    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

    try {
      var res = await fetch(searchUrl, { method: 'GET', headers: { 'User-Agent': ua } });
      if (!res.ok) return results;
      var html = await res.text();

      var rowsToProcess = [];

      if (typeof cheerio !== 'undefined' && cheerio.load) {
        var $ = cheerio.load(html);
        $('.tgxtablerow').each(function (i, el) {
          if (rowsToProcess.length >= 10) return;
          var row = $(el);
          var titleAnchor = row.find('a[title]').first();
          var tName = titleAnchor.attr('title') ? titleAnchor.attr('title').trim() : '';
          var postPath = titleAnchor.attr('href') || '';
          var size = row.find('.badge-secondary').text().trim() || 'Unknown';
          var seeds = parseInt(row.find('font[color="green"] b').first().text().trim()) || 0;

          if (tName && postPath) {
            rowsToProcess.push({
              title: tName,
              detailUrl: 'https://torrentgalaxy.info' + postPath,
              size: size,
              seeds: seeds
            });
          }
        });
      }

      for (var i = 0; i < rowsToProcess.length; i++) {
        var item = rowsToProcess[i];
        try {
          var detailRes = await fetch(item.detailUrl, { method: 'GET', headers: { 'User-Agent': ua } });
          if (detailRes.ok) {
            var detailHtml = await detailRes.text();
            var magMatch = detailHtml.match(/href="(magnet:\?xt=urn:btih:([a-zA-Z0-9]+)[^"]*)"/i);
            if (magMatch) {
              var magnet = magMatch[1];
              var hash = magMatch[2].toLowerCase();

              results.push({
                name: 'PlayTorrio',
                addonName: 'PlayTorrio',
                title: item.title,
                description: '👤 ' + item.seeds + ' seeds · 💾 ' + item.size + ' · TorrentGalaxy',
                url: magnet,
                headers: {},
                quality: 'HD',
                codec: '',
                isTorrent: true,
                infoHash: hash,
                seeds: item.seeds
              });
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      console.log('TorrentGalaxyScraper JS error:', e);
    }
    return results;
  }
};
