const https = require('https');

let cookieJar = {};

function request(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(targetUrl);
    const cookieStr = Object.entries(cookieJar)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');

    const bodyStr = options.body || null;

    const req = https.request(
      targetUrl,
      {
        method: options.method || 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: options.referer || 'https://clicknupload.click/',
          Cookie: cookieStr,
          ...(bodyStr ? { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(bodyStr) } : {}),
          ...options.headers,
        },
      },
      (res) => {
        if (res.headers['set-cookie']) {
          for (const c of res.headers['set-cookie']) {
            const [kv] = c.split(';');
            const [k, v] = kv.split('=');
            cookieJar[k.trim()] = v ? v.trim() : '';
          }
        }

        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function main() {
  const startUrl = 'https://clicknupload.click/cm3qzicoosev';
  const res1 = await request(startUrl);

  const formMatch1 = res1.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  console.log('Form 1 HTML snippet:\n', formMatch1[1]);

  const inputs1 = [...formMatch1[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params1 = new URLSearchParams();
  for (const im of inputs1) params1.append(im[1], im[2]);
  params1.append('method_free', 'Slow Download');

  const res2 = await request(startUrl, {
    method: 'POST',
    body: params1.toString(),
    referer: startUrl,
  });

  console.log('\n--- Step 2 Response ---');
  console.log('Status:', res2.status, 'Headers:', res2.headers);
  console.log('Body:\n', res2.body);
}

main();
