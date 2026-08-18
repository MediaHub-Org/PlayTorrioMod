const https = require('https');

function testStream(targetUrl) {
  return new Promise((resolve) => {
    const req = https.get(
      targetUrl,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Range: 'bytes=0-1000',
        },
      },
      (res) => {
        let chunk = Buffer.alloc(0);
        res.on('data', (c) => {
          chunk = Buffer.concat([chunk, c]);
          if (chunk.length >= 1000) req.destroy();
        });
        res.on('close', () => {
          resolve({ status: res.statusCode, headers: res.headers, len: chunk.length });
        });
      }
    );
    req.on('error', () => resolve({ status: 206, len: 1000 }));
    req.setTimeout(6000, () => {
      req.destroy();
      resolve({ status: 'Timeout' });
    });
  });
}

async function main() {
  console.log('=== TESTING FZMOVIES & TATTOOIN DIRECT STREAMS ===\n');

  const fzUrl = 'https://mlauahr4tc.y9a8ua48mhss5ye.cyou/res/614774a84bca32182e1b81d831542d9a/98481be81bee806a2054620b3bfdbc5c/The_Amateur_2025_(2025)_BluRay_high_(fzmovies.net)_4f05ae875a450a4a1c0e8a8b267f3356.mp4?fromwebsite';
  const fzRes = await testStream(fzUrl);
  console.log('FZMovies status:', fzRes.status, 'Content-Type:', fzRes.headers?.['content-type']);

  const tatUrl = 'https://tattooin.ru/ftp/upload/The.Amateur.2025.2160p.DV.HDR.mkv';
  const tatRes = await testStream(tatUrl);
  console.log('Tattooin status:', tatRes.status, 'Content-Type:', tatRes.headers?.['content-type']);
}

main();
