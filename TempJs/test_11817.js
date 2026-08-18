const https = require('https');

const payload = {
  mode: 'movie',
  title: '11817',
  year: '2026',
  tmdb_id: 1284041,
  imdb_id: 'tt32268156',
};

console.log('Testing payload for 11817:', payload);

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
          console.log('[Line from slave]:', l.trim().substring(0, 150));
        }
      }
    });
    res.on('end', () => {
      if (buffer.trim()) console.log('[Final line]:', buffer.trim().substring(0, 150));
      console.log('Stream ended.');
    });
  }
);

req.on('error', console.error);
req.write(bodyStr);
req.end();
