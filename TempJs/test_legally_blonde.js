const https = require('https');

async function testLegallyBlonde() {
  const payload = {
    mode: 'movie',
    title: 'Legally Blonde',
    year: '2001',
    tmdb_id: 8835,
    imdb_id: 'tt0250494',
  };

  console.log('Querying slave for Legally Blonde (2001)...');

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
                for (const link of p.links) {
                  console.log(`[Hit from ${p.site}] (${link.tags?.join(', ')}) URL: ${link.url}`);
                }
              }
            } catch (e) {}
          }
        }
      });
      res.on('end', () => console.log('Finished streaming.'));
    }
  );
  req.write(bodyStr);
  req.end();
}

testLegallyBlonde();
