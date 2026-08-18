const https = require('https');

function post(url, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const bodyStr = typeof data === 'string' ? data : JSON.stringify(data);

    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port || 443,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        Origin: 'https://downloadeverythingfromeverywhere.com',
        Referer: 'https://downloadeverythingfromeverywhere.com/',
        ...headers,
      },
    };

    const req = https.request(options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => (responseBody += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(responseBody) });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: responseBody });
        }
      });
    });

    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

async function testSlave() {
  console.log('=== 1. TESTING MOVIE REQUEST TO SLAVE ===\n');

  const moviePayload = {
    mode: 'movie',
    title: 'Obsession',
    year: '2026',
    tmdb_id: 1339713,
    imdb_id: 'tt37287335',
  };

  console.log('Sending Movie Payload:', moviePayload);
  const movieRes = await post('https://slave.downloadeverythingfromeverywhere.com/', moviePayload);
  console.log('Movie Status:', movieRes.status);
  console.log('Movie Response:\n', JSON.stringify(movieRes.data || movieRes.raw, null, 2));

  console.log('\n=== 2. TESTING TV SHOW REQUEST TO SLAVE ===\n');

  // Let's test House of the Dragon or another show (e.g. tmdb 94997)
  const showPayload = {
    mode: 'series',
    title: 'House of the Dragon',
    year: '2022',
    tmdb_id: 94997,
    imdb_id: 'tt11198330',
    season: 1,
    episode: 1,
  };

  console.log('Sending Show Payload:', showPayload);
  const showRes = await post('https://slave.downloadeverythingfromeverywhere.com/', showPayload);
  console.log('Show Status:', showRes.status);
  console.log('Show Response:\n', JSON.stringify(showRes.data || showRes.raw, null, 2));
}

testSlave();
