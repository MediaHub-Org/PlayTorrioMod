/**
 * Videasy JS Scraper Plugin for PlayTorrio
 */
var VideasyScraper = {
  name: 'PlayTorrioHTTP',
  provider: 'Videasy',
  id: 'videasy_v1',
  version: '1.0.0',

  scrape: async function (params) {
    var type = params.type === 'tv' || params.type === 'series' ? 'tv' : 'movie';
    var title = params.title || '';
    var tmdbId = params.tmdbId;
    var imdbId = params.imdbId || '';
    var year = params.year;
    var season = params.season || 1;
    var episode = params.episode || 1;

    var results = [];
    if (!tmdbId) return results;

    var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    var defaultHeaders = {
      'User-Agent': ua,
      'Referer': 'https://player.videasy.to/',
      'Origin': 'https://player.videasy.to',
      'Accept': 'application/json, text/plain, */*'
    };

    var providers = [
      { path: '/cdn/sources-with-title', label: 'Yoru' },
      { path: '/neon2/sources-with-title', label: 'Neon' },
      { path: '/m4uhd/sources-with-title', label: 'Breach' },
      { path: '/meine/sources-with-title', label: 'Killjoy' },
      { path: '/lamovie/sources-with-title', label: 'Omen' }
    ];

    try {
      // 1. Get Seed
      var seedRes = await fetch('https://api.speedracelight.com/seed?mediaId=' + tmdbId, { method: 'GET', headers: defaultHeaders });
      if (!seedRes.ok) return results;
      var seedData = await seedRes.json();
      var seed = seedData.seed;
      if (!seed) return results;

      var isTv = (type === 'tv');
      var qParams = [
        'title=' + encodeURIComponent(title),
        'mediaType=' + (isTv ? 'tv' : 'movie'),
        'tmdbId=' + tmdbId,
        'enc=2',
        'seed=' + seed
      ];
      if (year) qParams.push('year=' + year);
      if (imdbId) qParams.push('imdbId=' + encodeURIComponent(imdbId));
      if (isTv) {
        qParams.push('seasonId=' + season);
        qParams.push('episodeId=' + episode);
      }

      var queryString = qParams.join('&');

      for (var p = 0; p < providers.length; p++) {
        if (results.length >= 6) break;
        var prov = providers[p];
        var provUrl = 'https://api.speedracelight.com' + prov.path + '?' + queryString;

        try {
          var pRes = await fetch(provUrl, { method: 'GET', headers: defaultHeaders });
          if (!pRes.ok) continue;
          var body = await pRes.text();
          body = body.trim();
          if (body.startsWith('"') && body.endsWith('"')) {
            body = JSON.parse(body);
          }

          // Decrypt payload using mvm1 cipher
          var decryptedJson = VideasyScraper._decryptPayload(body, seed, parseInt(tmdbId));
          var data = JSON.parse(decryptedJson);
          var rawSources = data.sources || [];

          for (var s = 0; s < rawSources.length; s++) {
            var src = rawSources[s];
            var streamUrl = src.url || src.file;
            if (!streamUrl || !streamUrl.startsWith('http')) continue;
            var q = src.quality ? String(src.quality) : 'Auto';

            results.push({
              name: 'PlayTorrioHTTP',
              addonName: 'PlayTorrioHTTP',
              title: 'Videasy ' + prov.label + ' · ' + q,
              description: 'Videasy Multi-CDN HLS Stream',
              url: streamUrl,
              headers: {
                'User-Agent': ua,
                'Referer': 'https://player.videasy.to/'
              },
              quality: q,
              codec: 'h264',
              isTorrent: false,
              infoHash: null,
              seeds: 0
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      console.log('VideasyScraper error:', e);
    }
    return results;
  },

  // mvm1 cipher PRNG XOR logic
  _f: [1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580],
  _magic: [109, 118, 109, 49],

  _imul: function (a, b) { return Math.imul ? Math.imul(a, b) : (a | 0) * (b | 0); },
  _mix: function (e) {
    e &= 0xffffffff; e ^= (e >>> 16);
    e = Math.imul(e, 2246822507) & 0xffffffff;
    e ^= (e >>> 13);
    e = Math.imul(e, 3266489909) & 0xffffffff;
    return (e ^ (e >>> 16)) & 0xffffffff;
  },
  _rotl: function (e, t) {
    e &= 0xffffffff; t &= 31;
    if (t === 0) return e & 0xffffffff;
    return (((e << t) & 0xffffffff) | (e >>> (32 - t))) & 0xffffffff;
  },
  _fnv1a: function (e) {
    var t = 2166136261;
    for (var s = 0; s < e.length; s++) {
      t = Math.imul(t ^ e.charCodeAt(s), 16777619) & 0xffffffff;
    }
    return VideasyScraper._mix(t);
  },
  _accSeed: function (e) {
    var t = 1732584193;
    for (var s = 0; s < e.length; s++) {
      t = VideasyScraper._rotl((t ^ Math.imul(e.charCodeAt(s), VideasyScraper._f[15 & s])) & 0xffffffff, 5);
    }
    return VideasyScraper._mix(t);
  },
  _rc4Sbox: function (e) {
    var t = []; for (var i = 0; i < 256; i++) t.push(i);
    var s = 0;
    for (var a = 0; a < 256; a++) {
      s = (s + t[a] + e.charCodeAt(a % e.length)) & 255;
      var r = t[a]; t[a] = t[s]; t[s] = r;
    }
    return t;
  },
  _buildState: function (seed, mediaId) {
    if ((((seed.length * (seed.length + 1)) & 1) === 1)) {
      return { S: VideasyScraper._rc4Sbox(seed), acc: VideasyScraper._accSeed(seed) };
    }
    var s = new Array(61);
    var a = VideasyScraper._mix(VideasyScraper._fnv1a(seed) ^ VideasyScraper._mix((mediaId & 0xffffffff) ^ 2654435769)) & 0xffffffff;
    for (var e = 0; e < 8; e++) {
      if ((((e * (e + 1)) & 1) === 0)) {
        var t = Math.abs(a) % 61;
        a = VideasyScraper._rotl((a + 2654435769) & 0xffffffff, 7 + (7 & e));
        s[t] = (a ^ VideasyScraper._mix(a)) & 0xffffffff;
        a = VideasyScraper._mix((a + t) & 0xffffffff);
      } else {
        s[e] = VideasyScraper._f[15 & e];
      }
    }
    return { S: s, acc: VideasyScraper._mix(2779096485 ^ a) & 0xffffffff };
  },
  _nextWord: function (state, counter) {
    var r = state.S;
    var acc = state.acc;
    var n = Math.abs(acc) % 61;
    var exists = n < r.length && r[n] !== undefined && r[n] !== null;
    var i = 0 - (exists ? 1 : 0);
    var l = (exists ? r[n] : 0) & 0xffffffff;
    var a = (l ^ (Math.imul(2654435769, counter + 1) & 0xffffffff)) & 0xffffffff;
    var d = (((acc ^ a) & 0xffffffff) | (((acc & a & i) & 0xffffffff))) & 0xffffffff;
    d = (VideasyScraper._rotl((d + acc) & 0xffffffff, 31 & n) ^ VideasyScraper._rotl(acc, 31 & Math.imul(n, 7))) & 0xffffffff;
    acc = VideasyScraper._mix((d + 2654435769) & 0xffffffff);
    if (n < r.length) r[n] = acc & 0xffffffff;
    state.acc = acc;
    return acc & 0xffffffff;
  },
  _keystream: function (seed, mediaId, len) {
    var state = VideasyScraper._buildState(seed, mediaId);
    var out = new Uint8Array(len);
    var counter = 0;
    var e = 0;
    while (e < len) {
      var t = VideasyScraper._nextWord(state, counter++);
      out[e++] = 255 & t;
      if (e < len) out[e++] = (t >> 8) & 255;
      if (e < len) out[e++] = (t >> 16) & 255;
      if (e < len) out[e++] = (t >> 24) & 255;
    }
    return out;
  },
  _decryptPayload: function (payload, seed, mediaId) {
    var normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
    while (normalized.length % 4 !== 0) normalized += '=';

    var binaryStr = atob(normalized);
    var r = new Uint8Array(binaryStr.length);
    for (var i = 0; i < binaryStr.length; i++) r[i] = binaryStr.charCodeAt(i);

    var o = VideasyScraper._keystream(seed, mediaId, r.length);
    var decrypted = new Uint8Array(r.length);
    for (var e = 0; e < r.length; e++) decrypted[e] = r[e] ^ o[e];

    for (var m = 0; m < VideasyScraper._magic.length; m++) {
      if (decrypted[m] !== VideasyScraper._magic[m]) {
        throw new Error('Videasy decrypt magic mismatch');
      }
    }

    var text = '';
    for (var k = VideasyScraper._magic.length; k < decrypted.length; k++) {
      text += String.fromCharCode(decrypted[k]);
    }
    return decodeURIComponent(escape(text));
  }
};
