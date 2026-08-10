/**
 * Knaben Torrent JS Scraper Plugin for PlayTorrio
 * Uses Cheerio for HTML parsing
 */
var KnabenScraper = {
  name: 'PlayTorrio',
  provider: 'Knaben',
  id: 'knaben_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var title = params.title || '';
    var year = params.year ? String(params.year) : '';
    var season = params.season;
    var episode = params.episode;
    var type = params.type;

    var query = title;
    if (type === 'tv' || type === 'series') {
      var sStr = (season < 10 ? '0' : '') + season;
      var eStr = (episode < 10 ? '0' : '') + episode;
      query += ' S' + sStr + 'E' + eStr;
    } else if (year) {
      query += ' ' + year;
    }

    var searchUrl = 'https://knaben.eu/search/' + encodeURIComponent(query);
    var headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Referer': 'https://knaben.eu/'
    };

    var results = [];
    try {
      var res = await fetch(searchUrl, { method: 'GET', headers: headers });
      if (!res.ok) return results;
      var html = await res.text();

      // Cheerio DOM parsing
      if (typeof cheerio !== 'undefined' && cheerio.load) {
        var $ = cheerio.load(html);
        $('table tbody tr').each(function (i, el) {
          if (results.length >= 10) return;
          var row = $(el);
          var titleAnchor = row.find('td:nth-child(2) a').first();
          var itemTitle = titleAnchor.text().trim();
          var magnet = row.find('a[href^="magnet:"]').attr('href');

          if (itemTitle && magnet) {
            var seedsStr = row.find('td:nth-child(5)').text().trim();
            var seeds = parseInt(seedsStr) || 0;
            var sizeStr = row.find('td:nth-child(4)').text().trim() || 'Unknown';

            // Extract infoHash from magnet link
            var hashMatch = magnet.match(/btih:([a-zA-Z0-9]+)/i);
            var infoHash = hashMatch ? hashMatch[1].toLowerCase() : null;

            results.push({
              name: 'PlayTorrio',
              addonName: 'PlayTorrio',
              title: itemTitle,
              description: '👤 ' + seeds + ' seeds · 💾 ' + sizeStr + ' · Knaben',
              url: magnet,
              headers: {},
              quality: 'HD',
              codec: '',
              isTorrent: true,
              infoHash: infoHash,
              seeds: seeds
            });
          }
        });
      } else {
        // Fallback Regex if cheerio not loaded
        var rowRegex = /<tr[\s\S]*?<\/tr>/gi;
        var magnetRegex = /href="(magnet:\?xt=urn:btih:([a-zA-Z0-9]+)[^"]*)"/i;
        var titleRegex = /<a[^>]*class="[^"]*title[^"]*"[^>]*>([^<]+)<\/a>/i;

        var matches = html.match(rowRegex) || [];
        for (var i = 0; i < matches.length; i++) {
          if (results.length >= 10) break;
          var r = matches[i];
          var magM = r.match(magnetRegex);
          var titleM = r.match(titleRegex);

          if (magM && titleM) {
            var magnet = magM[1];
            var hash = magM[2].toLowerCase();
            var itemTitle = titleM[1].trim();

            results.push({
              name: 'PlayTorrio',
              addonName: 'PlayTorrio',
              title: itemTitle,
              description: 'Knaben Torrent Stream',
              url: magnet,
              headers: {},
              quality: 'HD',
              codec: '',
              isTorrent: true,
              infoHash: hash,
              seeds: 0
            });
          }
        }
      }
    } catch (e) {
      console.log('KnabenScraper JS error:', e);
    }
    return results;
  }
};
