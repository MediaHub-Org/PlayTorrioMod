const https = require('https');

function streamSlave(payload) {
  return new Promise((resolve, reject) => {
    const bodyStr = JSON.stringify(payload);
    const options = {
      hostname: 'slave.downloadeverythingfromeverywhere.com',
      port: 443,
      path: '/',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        Origin: 'https://downloadeverythingfromeverywhere.com',
        Referer: 'https://downloadeverythingfromeverywhere.com/',
      },
    };

    const hits = [];

    const req = https.request(options, (res) => {
      let buffer = '';
      res.on('data', (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop(); // keep remainder
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;
          try {
            const parsed = JSON.parse(trimmed);
            if (parsed.t === 'hit' && parsed.links) {
              console.log(`[Hit] Site: ${parsed.site} | Links found: ${parsed.links.length}`);
              hits.push(parsed);
            }
          } catch (e) {}
        }
      });

      res.on('end', () => {
        if (buffer.trim()) {
          try {
            const parsed = JSON.parse(buffer.trim());
            if (parsed.t === 'hit' && parsed.links) hits.push(parsed);
          } catch (e) {}
        }
        resolve(hits);
      });
    });

    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

async function main() {
  console.log('=== COLLECTING SLAVE SOURCES FOR MOVIE & TV ===\n');

  // Test Movie 1: Obsession (2026) TMDB 1339713
  console.log('--- 1. Movie: Obsession (2026) ---');
  const movieHits = await streamSlave({
    mode: 'movie',
    title: 'Obsession',
    year: '2026',
    tmdb_id: 1339713,
    imdb_id: 'tt37287335',
  });

  // Test Movie 2: Deadpool & Wolverine (2024) TMDB 533535
  console.log('\n--- 2. Movie: Deadpool & Wolverine (2024) ---');
  const dpHits = await streamSlave({
    mode: 'movie',
    title: 'Deadpool & Wolverine',
    year: '2024',
    tmdb_id: 533535,
    imdb_id: 'tt6263850',
  });

  const allLinks = [];
  for (const h of [...movieHits, ...dpHits]) {
    for (const l of h.links) {
      allLinks.push({ site: h.site, ...l });
    }
  }

  console.log(`\nTotal links collected: ${allLinks.length}`);
  const domains = new Map();
  for (const l of allLinks) {
    try {
      const u = new URL(l.url);
      const host = u.hostname;
      if (!domains.has(host)) domains.set(host, []);
      domains.get(host).push(l);
    } catch (e) {}
  }

  console.log('\n--- Grouped by Host Domain ---');
  for (const [host, links] of domains.entries()) {
    console.log(`\nDomain: ${host} (Total: ${links.length})`);
    for (const sample of links.slice(0, 3)) {
      console.log(`  - [${sample.site}] (${sample.tags ? sample.tags.join(', ') : 'no tags'}) ${sample.url}`);
    }
  }
}

main();
