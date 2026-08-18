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
  console.log('Step 1: GET', startUrl);
  const res1 = await request(startUrl);

  const formMatch1 = res1.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  const inputs1 = [...formMatch1[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params1 = new URLSearchParams();
  for (const im of inputs1) params1.append(im[1], im[2]);
  params1.append('method_free', 'Slow Download');

  console.log('Step 2: POST form 1 to', startUrl);
  const res2 = await request(startUrl, {
    method: 'POST',
    body: params1.toString(),
    referer: startUrl,
  });

  console.log('Step 2 HTML length:', res2.body.length);

  // Look for download form in step 2
  const formMatch2 = res2.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  const inputs2 = [...formMatch2[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params2 = new URLSearchParams();
  for (const im of inputs2) params2.append(im[1], im[2]);
  params2.append('down_script', '1');

  console.log('Waiting 5s for timer...');
  await new Promise((r) => setTimeout(r, 5000));

  console.log('Step 3: POST form 2 with down_script=1 to', startUrl);
  const res3 = await request(startUrl, {
    method: 'POST',
    body: params2.toString(),
    referer: startUrl,
  });

  console.log('Step 3 Status:', res3.status, 'Location:', res3.headers.location);
  console.log('Step 3 Content-Type:', res3.headers['content-type']);
  console.log('Step 3 HTML length:', res3.body.length);

  // Print all forms, buttons, scripts, or direct URLs
  require('fs').writeFileSync('TempJs/clickn_real_step3.html', res3.body);
  console.log('Saved TempJs/clickn_real_step3.html');
}

main();
