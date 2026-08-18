const https = require('https');
const http = require('http');

let cookieJar = {};

function request(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const cookieStr = Object.entries(cookieJar)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');

    const bodyStr = options.body || null;

    const req = client.request(
      targetUrl,
      {
        method: options.method || 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: options.referer || 'https://downloadeverythingfromeverywhere.com/',
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

async function studyClicknupload(targetUrl) {
  console.log(`\n========================================`);
  console.log(`Studying ClicknUpload: ${targetUrl}`);
  console.log(`========================================`);

  try {
    const res1 = await request(targetUrl);
    console.log('Step 1 status:', res1.status, 'HTML length:', res1.body.length);

    // Look for form
    const formMatch = res1.body.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
    if (formMatch) {
      console.log('Found POST form in Step 1!');
      const inputMatches = [...formMatch[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
      const formParams = new URLSearchParams();
      for (const im of inputMatches) {
        formParams.append(im[1], im[2]);
        console.log(`  Input: ${im[1]} = ${im[2]}`);
      }

      // Add submit button value if needed (e.g. method_free = "Free Download")
      if (!formParams.has('method_free')) formParams.append('method_free', 'Free Download');

      console.log('\n[Step 2] Sending POST form back to ClicknUpload...');
      const res2 = await request(targetUrl, {
        method: 'POST',
        body: formParams.toString(),
        referer: targetUrl,
      });

      console.log('Step 2 status:', res2.status, 'HTML length:', res2.body.length);

      // Search for download button or direct link
      const directLinks = [...res2.body.matchAll(/href=["'](https?:\/\/[^"']+\.(?:mkv|mp4|avi|webm)[^"']*)["']/gi)].map((m) => m[1]);
      console.log(`Found ${directLinks.length} direct video links in Step 2:`);
      for (const dl of directLinks) {
        console.log('  >>> DIRECT STREAM URL:', dl);
      }

      // Also search for download button / onClick
      const btnMatches = [...res2.body.matchAll(/href=["'](https?:\/\/[^"']+)["'][^>]*class=["'][^"']*download[^"']*["']/gi)].map((m) => m[1]);
      console.log('Download buttons:', btnMatches);

      // Look for script window.open / location
      const scriptLinks = [...res2.body.matchAll(/https?:\/\/[a-zA-Z0-9.\-_]+\/d\/[a-zA-Z0-9_\-\/]+/g)].map((m) => m[0]);
      console.log('d/ links:', scriptLinks);
    }
  } catch (e) {
    console.log('Error:', e.message);
  }
}

async function main() {
  await studyClicknupload('https://clicknupload.click/nm8ty9956ia8');
  await studyClicknupload('https://clicknupload.click/r6rhe06elzjh');
}

main();
