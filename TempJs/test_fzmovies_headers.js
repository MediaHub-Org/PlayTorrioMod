const https = require('https');
const { spawn } = require('child_process');

const mpvPath = 'C:\\ProgramData\\chocolatey\\lib\\mpvio.install\\tools\\mpv.com';
const testUrl = 'https://i9ijqt7aux.y9a8ua48mhss5ye.cyou/res/614774a84bca32182e1b81d831542d9a/8f5339f41936122d87f6b6398e8fddc2/Legally_Blonde_(2001)_BluRay_high_(fzmovies.net)_f33fcb442c538029ee53bb025bbe0c2b.mp4?fromwebsite';

function checkHttp(headers) {
  return new Promise((resolve) => {
    const req = https.get(
      testUrl,
      {
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
          if (chunk.length >= 1000) req.destroy();
        });
        res.on('close', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            bytes: chunk.length,
            bodySnippet: chunk.toString('utf8').substring(0, 150),
          });
        });
      }
    );
    req.on('error', (err) => resolve({ error: err.message }));
    req.setTimeout(8000, () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });
  });
}

function testMpv(headers = {}) {
  return new Promise((resolve) => {
    const headerArgs = Object.entries(headers).map(([k, v]) => `--http-header-fields=${k}: ${v}`);

    const args = [
      '--no-video',
      '--frames=10',
      '--msg-level=all=status',
      ...headerArgs,
      testUrl,
    ];

    console.log('Running MPV with args:', headerArgs.join(' '));
    const proc = spawn(mpvPath, args);

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => (stdout += d.toString()));
    proc.stderr.on('data', (d) => (stderr += d.toString()));

    proc.on('close', (code) => {
      resolve({ code, stdout: stdout.trim(), stderr: stderr.trim() });
    });
  });
}

async function main() {
  console.log('=== 1. TESTING DIFFERENT HEADERS ON FZMOVIES ===\n');

  // Test 1: No Referer
  console.log('[Test 1] No Referer...');
  const res1 = await checkHttp({});
  console.log('Status:', res1.status, 'Len:', res1.bytes, 'Snippet:', res1.bodySnippet);

  // Test 2: Referer = https://fzmovies.net/
  console.log('\n[Test 2] Referer: https://fzmovies.net/ ...');
  const res2 = await checkHttp({ Referer: 'https://fzmovies.net/' });
  console.log('Status:', res2.status, 'Len:', res2.bytes, 'Content-Type:', res2.headers?.['content-type']);

  // Test 3: Referer = https://www.fzmovies.net/
  console.log('\n[Test 3] Referer: https://www.fzmovies.net/ ...');
  const res3 = await checkHttp({ Referer: 'https://www.fzmovies.net/' });
  console.log('Status:', res3.status, 'Len:', res3.bytes);

  console.log('\n=== 2. TESTING PLAYBACK IN MPV WITH HEADERS ===\n');
  const mpvNoRef = await testMpv({});
  console.log('MPV without Referer code:', mpvNoRef.code, 'stdout:', mpvNoRef.stdout);

  const mpvWithRef = await testMpv({
    'Referer': 'https://fzmovies.net/',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  });
  console.log('\nMPV with Referer https://fzmovies.net/ code:', mpvWithRef.code);
  console.log('stdout:', mpvWithRef.stdout);
  console.log('stderr:', mpvWithRef.stderr);
}

main();
