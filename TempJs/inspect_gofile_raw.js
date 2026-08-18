const https = require('https');

function request(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: options.method || 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          ...options.headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, data }));
      }
    );
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  console.log('=== INSPECTING GOFILE RAW API ===\n');

  const accRes = await request('https://api.gofile.io/accounts', { method: 'POST' });
  console.log('Accounts endpoint status:', accRes.status, 'data:', accRes.data);

  let token = null;
  try {
    token = JSON.parse(accRes.data).data.token;
  } catch (e) {}

  console.log('Token:', token);

  const contentRes = await request('https://api.gofile.io/contents/oIdyKo?wt=4fd6sg89d7s6', {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });

  console.log('Content endpoint status:', contentRes.status);
  console.log('Content raw data:\n', contentRes.data);
}

main();
