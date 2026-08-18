const https = require('https');

const testUrl = 'https://clicknupload.click/cm3qzicoosev/tfpdl-furs1031080x.mkv';

function check(url) {
  return new Promise((resolve) => {
    https.get(
      url,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://clicknupload.click/',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          console.log('Status:', res.statusCode);
          console.log('Content-Type:', res.headers['content-type']);
          console.log('Location:', res.headers.location);
          console.log('Body length:', data.length);
          console.log('Body snippet:\n', data.substring(0, 600));
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        });
      }
    ).on('error', console.error);
  });
}

check(testUrl);
