const https = require('https');

async function checkMovie(tmdbId, title) {
  const payload = {
    mode: 'movie',
    title: title || 'Movie',
    tmdb_id: tmdbId,
  };

  const bodyStr = JSON.stringify(payload);
  const req = https.request(
    'https://slave.downloadeverythingfromeverywhere.com/',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        Origin: 'https://downloadeverythingfromeverywhere.com',
        Referer: 'https://downloadeverythingfromeverywhere.com/',
      },
    },
    (res) => {
      let hits = 0;
      let buffer = '';
      res.on('data', (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop();
        for (const l of lines) {
          if (l.trim()) {
            try {
              const p = JSON.parse(l.trim());
              if (p.t === 'hit' && p.links) {
                hits += p.links.length;
                console.log(`[${title || tmdbId}] Hit from ${p.site}: ${p.links.length} links (e.g. ${p.links[0].url})`);
              }
            } catch (e) {}
          }
        }
      });
      res.on('end', () => {
        console.log(`Total hits for ${title || tmdbId}: ${hits}\n`);
      });
    }
  );
  req.write(bodyStr);
  req.end();
}

async function main() {
  await checkMovie(1083381, 'The Amateur');
  await checkMovie(1339713, 'Obsession');
}

main();
