const https = require('https');

function req(targetUrl) {
  return new Promise((resolve, reject) => {
    https.get(
      targetUrl,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://downloadeverythingfromeverywhere.com/',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve(data));
      }
    ).on('error', reject);
  });
}

async function main() {
  const html = await req('https://driveseed.org/file/49wER1yqLyLpN6nnseSe');

  // Search for all anchor tags with buttons or onclick
  const buttons = [...html.matchAll(/<a[^>]+class="[^"]*btn[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi)];
  console.log(`Found ${buttons.length} buttons:`);
  for (const b of buttons) {
    console.log(`  -> Link: ${b[1]} | Text: ${b[2].replace(/<[^>]+>/g, '').trim()}`);
  }

  // Search for all script tags
  const scripts = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
  console.log(`\nFound ${scripts.length} scripts:`);
  for (const s of scripts) {
    if (s.includes('http') || s.includes('download') || s.includes('location')) {
      console.log('Script snippet:\n', s.substring(0, 400));
    }
  }
}

main();
