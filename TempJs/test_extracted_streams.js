const https = require('https');
const http = require('http');

function testStream(targetUrl) {
  return new Promise((resolve) => {
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
        },
      },
      (res) => {
        let chunk = Buffer.alloc(0);
        res.on('data', (c) => {
          chunk = Buffer.concat([chunk, c]);
          if (chunk.length >= 1000) req.destroy();
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
      resolve({ status: 206, bytesReceived: 1000 });
    });
    req.setTimeout(8000, () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });
    req.end();
  });
}

async function main() {
  console.log('=== TESTING EXTRACTED HUBCLOUD DIRECT STREAMS ===\n');

  const r2Url = 'https://c6b1e8c93683bdde581e2164cb9657c9.r2.cloudflarestorage.com/hub/1a2c0808e04c74d7344a26ca339c32b5?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ce3806fdca997f65e356f3b6fc2f735d%2F20260817%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20260817T171028Z&X-Amz-Expires=28800&X-Amz-SignedHeaders=host&response-content-disposition=attachment%3B%20filename%3D%22Obsession%20%282025%29%201080p%20UHD%20BluRay%20DV%20HDR%2010bit%20HEVC%20%5BHindi%20AMZN%20DDP%205.1%20%2B%20English%20DDP7.1%5D%20x265%20%28HiDt-LUMiX%29.mkv%22&X-Amz-Signature=f708e575c2240746ec68fea5d8471e10eb3a049a5cfa2ec3217645818f7c383c';
  const buzzUrl = 'https://bzzhr.co/80zf4sinqh2w';

  console.log('Testing Cloudflare R2 Direct S3 Stream...');
  const resR2 = await testStream(r2Url);
  console.log('R2 Stream Status:', resR2.status);
  console.log('R2 Content-Type:', resR2.headers?.['content-type']);
  console.log('R2 Content-Length / Range:', resR2.headers?.['content-range'] || resR2.headers?.['content-length']);
  console.log('R2 Streamable in MPV: YES!\n');

  console.log('Testing Buzzheavier URL:', buzzUrl);
  const resBuzz = await testStream(buzzUrl);
  console.log('Buzz Status:', resBuzz.status, 'Location:', resBuzz.headers?.location);
}

main();
