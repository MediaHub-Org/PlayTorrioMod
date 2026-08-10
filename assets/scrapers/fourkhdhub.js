/**
 * 4KHDHub JS Scraper Plugin for PlayTorrio
 * 1:1 Port of FourKHDHubScraper
 */
var FourKHDHubScraper = {
  name: 'PlayTorrioHTTP',
  provider: '4KHDHub',
  id: 'fourkhdhub_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var title = params.title || '';
    var year = params.year;
    var type = params.type;
    var season = params.season;
    var episode = params.episode;
    var results = [];

    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    var headers = { 'User-Agent': ua };

    try {
      var isTv = (type === 'series' || type === 'tv');
      var searchUrl = 'https://4khdhub.one/?s=' + encodeURIComponent(title);
      var res = await fetch(searchUrl, { method: 'GET', headers: headers });
      if (!res.ok) return results;
      var html = await res.text();

      var detailUrl = null;
      if (typeof cheerio !== 'undefined' && cheerio.load) {
        var $ = cheerio.load(html);
        $('article, .post-item, .result-item').each(function (i, el) {
          var link = $(el).find('a').first();
          var t = (link.attr('title') || link.text() || '').trim().toLowerCase();
          var cleanT = t.replace(/[^a-z0-9]/g, '');
          var cleanSearch = title.toLowerCase().replace(/[^a-z0-9]/g, '');

          if (cleanT.indexOf(cleanSearch) !== -1) {
            detailUrl = link.attr('href');
            return false;
          }
        });
      }

      if (!detailUrl) {
        var m = html.match(/href="(https:\/\/4khdhub\.one\/[^"]+)"/i);
        if (m) detailUrl = m[1];
      }

      if (!detailUrl) return results;

      var detailRes = await fetch(detailUrl, { method: 'GET', headers: headers });
      if (!detailRes.ok) return results;
      var detailHtml = await detailRes.text();

      var downloadLinks = [];
      if (typeof cheerio !== 'undefined' && cheerio.load) {
        var $d = cheerio.load(detailHtml);
        if (isTv && season && episode) {
          var sPad = (season < 10 ? '0' : '') + season;
          var ePad = (episode < 10 ? '0' : '') + episode;
          var epCode = 'S' + sPad + 'E' + ePad;

          $d('.episode-item, tr, p').each(function (i, el) {
            var txt = $d(el).text();
            if (txt.indexOf(epCode) !== -1) {
              $d(el).find('a[href*="hubcloud"]').each(function (j, a) {
                downloadLinks.push($d(a).attr('href'));
              });
            }
          });
        }

        if (downloadLinks.length === 0) {
          $d('a[href*="hubcloud"]').each(function (i, a) {
            downloadLinks.push($d(a).attr('href'));
          });
        }
      }

      if (downloadLinks.length === 0) {
        var linkMatches = detailHtml.match(/href="(https:\/\/hubcloud\.[^"]+)"/gi) || [];
        for (var i = 0; i < linkMatches.length; i++) {
          var lM = linkMatches[i].match(/href="([^"]+)"/i);
          if (lM && lM[1] && downloadLinks.indexOf(lM[1]) === -1) {
            downloadLinks.push(lM[1]);
          }
        }
      }

      for (var k = 0; k < downloadLinks.length && results.length < 8; k++) {
        var dUrl = downloadLinks[k];
        try {
          var redRes = await fetch(dUrl, { method: 'GET', headers: headers });
          var finalUrl = redRes.url || dUrl;
          if (finalUrl && finalUrl.startsWith('http') && finalUrl.indexOf('hubcloud') === -1) {
            results.push({
              name: 'PlayTorrioHTTP',
              addonName: 'PlayTorrioHTTP',
              title: '4KHDHub ' + title + ' #' + (results.length + 1),
              description: '4KHDHub Direct Fast Stream',
              url: finalUrl,
              headers: { 'User-Agent': ua },
              quality: 'HD',
              codec: 'h265',
              isTorrent: false,
              infoHash: null,
              seeds: 0
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      console.log('FourKHDHubScraper JS error:', e);
    }
    return results;
  }
};
