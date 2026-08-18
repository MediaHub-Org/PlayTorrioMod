const https = require('https');

function req(targetUrl) {
  return new Promise((resolve) => {
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
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
  });
}

async function main() {
  console.log('=== TESTING FILEBEE & VIKINGFILE ===\n');

  const fbUrl = 'https://filebee.xyz/file/6a464cc986d6cba554c2af7f';
  const resFb = await req(fbUrl);
  console.log('Filebee status:', resFb.status, 'HTML len:', resFb.body.length);
  const fbDirect = [...resFb.body.matchAll(/href="([^"]+)"/g)].map((m) => m[1]).filter((l) => l.includes('download') || l.includes('.mkv') || l.includes('stream'));
  console.log('Filebee stream links:', fbDirect);

  const vkUrl = 'https://vikingfile.com/f/P1d8yqTnl9';
  const resVk = await req(vkUrl);
  console.log('\nVikingfile status:', resVk.status, 'HTML len:', resVk.body.length);
  const vkDirect = [...resVk.body.matchAll(/href="([^"]+)"/g)].map((m) => m[1]).filter((l) => l.includes('download') || l.includes('.mkv') || l.includes('stream'));
  console.log('Vikingfile stream links:', vkDirect);
}

main();
