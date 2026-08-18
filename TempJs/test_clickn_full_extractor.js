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
    req.setTimeout(12000, () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function extractClicknUpload(startUrl) {
  console.log(`Extracting ClicknUpload: ${startUrl}`);

  // Step 1: Initial page load
  const res1 = await request(startUrl);
  const formMatch1 = res1.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  if (!formMatch1) return null;

  const inputs1 = [...formMatch1[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params1 = new URLSearchParams();
  for (const im of inputs1) params1.append(im[1], im[2]);
  if (!params1.has('method_free')) params1.append('method_free', 'Slow Download');

  // Step 2: Post to get download form with countdown
  const res2 = await request(startUrl, {
    method: 'POST',
    body: params1.toString(),
    referer: startUrl,
  });

  const formMatch2 = res2.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  if (!formMatch2) return null;

  const inputs2 = [...formMatch2[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params2 = new URLSearchParams();
  for (const im of inputs2) params2.append(im[1], im[2]);
  params2.append('down_script', '1');

  // Wait 4-5s countdown
  console.log('Waiting 5s for countdown...');
  await new Promise((r) => setTimeout(r, 5000));

  // Step 3: Final submit
  const res3 = await request(startUrl, {
    method: 'POST',
    body: params2.toString(),
    referer: startUrl,
  });

  console.log('Final status:', res3.status, 'Location:', res3.headers.location);

  // Look for direct link
  const directMatch = res3.body.match(/https?:\/\/[a-zA-Z0-9.\-_:]+\/d\/[a-zA-Z0-9_\-\/]+/i) || res3.body.match(/window\.open\(['"]([^'"]+)['"]/i) || res3.body.match(/href=["'](https?:\/\/[^"']+\.(?:mkv|mp4)[^"']*)["']/i);

  if (directMatch) {
    console.log('[+] Direct Stream URL Found:', directMatch[1] || directMatch[0]);
    return directMatch[1] || directMatch[0];
  }

  return null;
}

async function main() {
  const testUrls = [
    'https://clicknupload.click/nm8ty9956ia8',
    'https://clicknupload.click/r6rhe06elzjh',
  ];

  for (const tu of testUrls) {
    const directLink = await extractClicknUpload(tu);
    console.log('Result:', directLink);
  }
}

main();
