const https = require('https');
const { spawn } = require('child_process');

const mpvPath = 'C:\\ProgramData\\chocolatey\\lib\\mpvio.install\\tools\\mpv.com';

function req(targetUrl) {
  return new Promise((resolve) => {
    https.get(
      targetUrl,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://downloadeverythingfromeverywhere.com/',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
  });
}

async function main() {
  const url = 'https://a.111477.xyz/movies/Obsession%20%282026%29/Obsession.2026.1080p.DS4K.WEBRip.10bit.DDP5.1.Atmos.x265-NeoNoir.mkv';
  const res = await req(url);
  console.log('111477 Status:', res.status, 'Location:', res.headers.location);

  if (res.headers.location) {
    console.log('Redirect location:', res.headers.location);
    const res2 = await req(res.headers.location);
    console.log('Destination Status:', res2.status, 'Headers:', res2.headers);
  }
}

main();
