const https = require('https');

function requestJson(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const bodyStr = options.body ? JSON.stringify(options.body) : null;

    const req = https.request(
      url,
      {
        method: options.method || 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Accept: 'application/json',
          ...(bodyStr ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(bodyStr) } : {}),
          ...options.headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(data) });
          } catch (e) {
            resolve({ status: res.statusCode, headers: res.headers, raw: data });
          }
        });
      }
    );

    req.on('error', reject);
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

let cachedGofileToken = null;

async function getGofileToken() {
  if (cachedGofileToken) return cachedGofileToken;
  try {
    const res = await requestJson('https://api.gofile.io/accounts', { method: 'POST' });
    if (res.data?.status === 'ok' && res.data.data?.token) {
      cachedGofileToken = res.data.data.token;
      return cachedGofileToken;
    }
  } catch (e) {}
  return null;
}

async function extractGofile(gofileUrl) {
  const match = gofileUrl.match(/gofile\.io\/d\/([a-zA-Z0-9_-]+)/);
  if (!match) return null;
  const contentId = match[1];

  const token = await getGofileToken();
  const headers = token ? { Authorization: `Bearer ${token}` } : {};

  // Fetch content
  const contentUrl = `https://api.gofile.io/contents/${contentId}?wt=4fd6sg89d7s6`;
  const res = await requestJson(contentUrl, { headers });

  if (res.data?.status === 'ok' && res.data.data?.children) {
    const children = res.data.data.children;
    const files = Object.values(children).filter((c) => c.type === 'file' || c.link);
    return files.map((f) => ({
      name: f.name,
      size: f.size,
      link: f.link,
      mimetype: f.mimetype,
      headers: {
        Cookie: `accountToken=${token}`,
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      },
    }));
  }
  return null;
}

async function main() {
  console.log('=== 2. STUDYING GOFILE EXTRACTOR ===\n');

  const testUrls = [
    'https://gofile.io/d/oIdyKo',
    'https://gofile.io/d/sJcgoQ',
    'https://gofile.io/d/aJZRTe',
    'https://gofile.io/d/cEExsE',
  ];

  for (const tu of testUrls) {
    console.log(`Checking Gofile: ${tu} ...`);
    try {
      const files = await extractGofile(tu);
      if (files && files.length) {
        console.log(`  [+] Found ${files.length} streamable files:`);
        for (const f of files) {
          console.log(`     * Name: ${f.name} (${Math.round((f.size || 0) / 1024 / 1024)} MB)`);
          console.log(`     * Direct Stream Link: ${f.link}`);
          console.log(`     * Headers:`, f.headers);
        }
      } else {
        console.log('  [-] No files found or link dead.');
      }
    } catch (e) {
      console.log('  [-] Extraction error:', e.message);
    }
    console.log('');
  }
}

main();
