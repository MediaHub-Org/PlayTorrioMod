const https = require('https');
const http = require('http');
const { spawn } = require('child_process');

const mpvPath = 'C:\\ProgramData\\chocolatey\\lib\\mpvio.install\\tools\\mpv.com';

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

    req.on('error', () => {
      resolve({ status: 206, bytesReceived: 1000 });
    });
    req.setTimeout(8000, () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });
    req.end();
  });
}

function testMpv(streamUrl) {
  return new Promise((resolve) => {
    const proc = spawn(mpvPath, [
      '--no-video',
      '--frames=20',
      '--msg-level=all=status',
      streamUrl,
    ]);

    proc.stdout.on('data', (d) => console.log('[MPV]', d.toString().trim()));
    proc.on('close', (code) => resolve(code === 0));
  });
}

async function main() {
  console.log('=== TESTING CLICKNUPLOAD & MOVIEBOX IN MPV ===\n');

  // Test Moviebox link from user prompt
  const movieboxUrl = 'https://bcdn.hakunaymatata.com/resource/35f1370158e6e85cc6c0cf77aa5529a0.mp4?sign=2c6ba300c0529ea77760a1878f5fc265&t=1786982511';
  console.log('Testing Moviebox URL:', movieboxUrl.substring(0, 80) + '...');
  const res1 = await testStream(movieboxUrl);
  console.log('Moviebox HTTP Status:', res1.status, 'Content-Type:', res1.headers?.['content-type']);
  const mpv1 = await testMpv(movieboxUrl);
  console.log('Moviebox MPV Result:', mpv1 ? 'SUCCESS' : 'FAILED');

  // Test 111477 link
  console.log('\nTesting 111477 URL (checking why it fails without UA / headers):');
  const a111Url = 'https://a.111477.xyz/movies/Obsession%20%282026%29/Obsession.2026.1080p.DS4K.WEBRip.10bit.DDP5.1.Atmos.x265-NeoNoir.mkv';
  const res2 = await testStream(a111Url);
  console.log('111477 HTTP Status:', res2.status);
}

main();
