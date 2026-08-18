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

async function main() {
  console.log('=== STUDYING CLICKNUPLOAD STEP 2 -> STEP 3 FINAL STREAM LINK ===\n');

  const startUrl = 'https://clicknupload.click/nm8ty9956ia8';
  const res1 = await request(startUrl);

  const formMatch1 = res1.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  const inputs1 = [...formMatch1[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
  const params1 = new URLSearchParams();
  for (const im of inputs1) params1.append(im[1], im[2]);
  if (!params1.has('method_free')) params1.append('method_free', 'Slow Download');

  console.log('[1] Submitting Step 1 form...');
  const res2 = await request(startUrl, {
    method: 'POST',
    body: params1.toString(),
    referer: startUrl,
  });

  console.log('Step 2 status:', res2.status, 'HTML len:', res2.body.length);

  // Look for step 2 form (op=download2)
  const formMatch2 = res2.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
  if (formMatch2) {
    console.log('\n[2] Found Step 2 POST form!');
    const inputs2 = [...formMatch2[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
    const params2 = new URLSearchParams();
    for (const im of inputs2) {
      params2.append(im[1], im[2]);
      console.log(`  Input: ${im[1]} = ${im[2]}`);
    }

    // Check if there is a countdown or delay
    const waitMatch = res2.body.match(/countdown[^>]*>(\d+)/i) || res2.body.match(/c=(\d+)/);
    const waitSec = waitMatch ? parseInt(waitMatch[1]) : 5;
    console.log(`Waiting ${waitSec + 1} seconds for download unlock...`);
    await new Promise((r) => setTimeout(r, (waitSec + 1) * 1000));

    console.log('\n[3] Submitting Step 2 form to get final direct download link...');
    const res3 = await request(startUrl, {
      method: 'POST',
      body: params2.toString(),
      referer: startUrl,
    });

    console.log('Step 3 status:', res3.status, 'Location:', res3.headers.location); require('fs').writeFileSync('TempJs/clickn_step3.html', res3.body);

    // Search for final direct video download link
    const finalLinks = [...res3.body.matchAll(/href=["'](https?:\/\/[^"']+)["']/gi)].map((m) => m[1]);
    console.log('Links on Step 3:');
    for (const fl of finalLinks) {
      if (fl.includes('.mkv') || fl.includes('.mp4') || fl.includes('download') || fl.includes('cloud')) {
        console.log('  >>> FINAL STREAM URL:', fl);
      }
    }
  }
}

main();
