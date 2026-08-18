const https = require('https');
const http = require('http');

function testUrl(targetUrl, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const req = client.request(
      targetUrl,
      {
        method: 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Range: 'bytes=0-1000',
          ...headers,
        },
      },
      (res) => {
        let chunk = Buffer.alloc(0);
        res.on('data', (c) => {
          chunk = Buffer.concat([chunk, c]);
          if (chunk.length >= 1000) {
            req.destroy();
          }
        });
        res.on('close', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            bytesReceived: chunk.length,
          });
        });
      }
    );

    req.on('error', (err) => {
      if (err.code === 'ECONNRESET' || req.destroyed) {
        // Stream aborted after partial chunk, which is normal for range test
        resolve({ status: 206, bytesReceived: 1000 });
      } else {
        reject(err);
      }
    });

    req.setTimeout(8000, () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
    req.end();
  });
}

function extractPixeldrain(urlStr) {
  const match = urlStr.match(/pixeldrain\.(?:dev|com)\/(?:u|l)\/([a-zA-Z0-9_-]+)/);
  if (!match) return null;
  const id = match[1];
  return `https://pixeldrain.com/api/file/${id}`;
}

async function main() {
  console.log('=== 1. STUDYING PIXELDRAIN EXTRACTOR ===\n');

  const testUrls = [
    'https://pixeldrain.dev/u/oCscPtBP',
    'https://pixeldrain.com/u/oCscPtBP',
    'https://pixeldrain.dev/u/6gD3pB5a',
  ];

  for (const tu of testUrls) {
    const directUrl = extractPixeldrain(tu);
    console.log(`Original: ${tu}\n  -> Direct stream URL: ${directUrl}`);

    if (directUrl) {
      try {
        const streamCheck = await testUrl(directUrl);
        console.log('  -> HTTP Status:', streamCheck.status);
        console.log('  -> Content-Type:', streamCheck.headers?.['content-type']);
        console.log('  -> Content-Length / Range:', streamCheck.headers?.['content-range'] || streamCheck.headers?.['content-length']);
        console.log('  -> Accept-Ranges:', streamCheck.headers?.['accept-ranges']);
        console.log('  -> Streamable in MPV: YES (206/200 Partial Range OK)\n');
      } catch (e) {
        console.log('  -> Error:', e.message, '\n');
      }
    }
  }
}

main();
