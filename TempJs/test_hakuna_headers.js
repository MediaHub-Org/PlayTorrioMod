const https = require('https');

const url = 'https://bcdn.hakunaymatata.com/bt/d29600de94c9d82aecb6391ef0529257.mp4?sign=7f5697ae4a47cdeed519d0ee4086d24a&t=1787034108';

function testReq(headers, label) {
  return new Promise((resolve) => {
    https.get(
      url,
      {
        headers,
      },
      (res) => {
        let chunk = Buffer.alloc(0);
        res.on('data', (c) => {
          chunk = Buffer.concat([chunk, c]);
          if (chunk.length >= 200) res.destroy();
        });
        res.on('close', () => {
          console.log(`[${label}] Status: ${res.statusCode} | Content-Type: ${res.headers['content-type']}`);
          resolve(res.statusCode);
        });
      }
    ).on('error', (e) => {
      console.log(`[${label}] Status: (closed after data)`);
      resolve(200);
    });
  });
}

async function main() {
  console.log('=== TESTING HAKUNAMATATA WITH DIFFERENT HEADERS ===\n');

  // Test 1: Default MPV User-Agent
  await testReq({ 'User-Agent': 'mpv 0.38.0' }, 'MPV User-Agent');

  // Test 2: No User-Agent / empty
  await testReq({}, 'No Headers');

  // Test 3: Lavf (ffmpeg) User-Agent
  await testReq({ 'User-Agent': 'Lavf/60.16.100' }, 'Lavf/FFmpeg');

  // Test 4: Chrome User-Agent
  await testReq(
    {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    'Chrome Desktop UA'
  );

  // Test 5: Moviebox App Mobile UA
  await testReq(
    {
      'User-Agent': 'MovieBox/1.0 (Android; Mobile)',
    },
    'MovieBox Mobile UA'
  );
}

main();
