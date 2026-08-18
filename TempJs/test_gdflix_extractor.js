const https = require('https');
const http = require('http');

function req(targetUrl, headers = {}, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const req = client.request(
      targetUrl,
      {
        method,
        rejectUnauthorized: false,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://downloadeverythingfromeverywhere.com/',
          ...headers,
        },
      },
      (res) => {
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
    if (body) req.write(body);
    req.end();
  });
}

async function studyGdflix(targetUrl) {
  console.log(`\n========================================`);
  console.log(`Studying GDFlix: ${targetUrl}`);
  console.log(`========================================`);

  try {
    const res = await req(targetUrl);
    console.log('Status:', res.status, 'Location:', res.headers.location, 'HTML len:', res.body.length);

    let html = res.body;
    if (res.status >= 300 && res.status < 400 && res.headers.location) {
      console.log('Following redirect to:', res.headers.location);
      const res2 = await req(res.headers.location, { Referer: targetUrl });
      html = res2.body;
    }

    console.log('HTML snippet:\n', html.substring(0, 800));

    // Look for download / fastcloud / stream buttons / forms
    const forms = [...html.matchAll(/<form[^>]+action="([^"]+)"[^>]*>([\s\S]*?)<\/form>/gi)];
    console.log(`\nFound ${forms.length} forms:`);
    for (const f of forms) {
      console.log('  -> Action:', f[1]);
      const inputs = [...f[2].matchAll(/name="([^"]+)"\s+value="([^"]*)"/gi)].map((m) => `${m[1]}=${m[2]}`);
      console.log('     Inputs:', inputs);
    }

    const links = [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
    console.log('\nDirect links on GDFlix page:');
    for (const l of links) {
      if (
        l.includes('download') ||
        l.includes('fastcloud') ||
        l.includes('drive') ||
        l.includes('pixeldrain') ||
        l.includes('gofile') ||
        l.includes('buzzheavier') ||
        l.includes('.mkv') ||
        l.includes('.mp4')
      ) {
        console.log('  [+] Link:', l);
      }
    }
  } catch (e) {
    console.log('Error:', e.message);
  }
}

async function main() {
  const gdUrls = [
    'https://gdflix.dev/file/hCClSjTY8HdiXUx',
    'https://gdflix.dev/file/DiJmBLIsqZlN3bD',
    'https://driveseed.org/file/49wER1yqLyLpN6nnseSe',
  ];

  for (const gu of gdUrls) {
    await studyGdflix(gu);
  }
}

main();
