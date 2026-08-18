const https = require('https');
const http = require('http');

function req(targetUrl, headers = {}) {
  return new Promise((resolve) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const r = client.get(
      targetUrl,
      {
        rejectUnauthorized: false,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://fzmovies.net/',
          ...headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    r.on('error', (err) => resolve({ error: err.message }));
  });
}

async function main() {
  console.log('=== STUDYING FZMOVIES RESOLUTION ===\n');

  // Let's search fzmovies directly
  const searchUrl = 'https://fzmovies.net/csearch.php?search=Legally+Blonde';
  console.log('Requesting search:', searchUrl);
  const searchRes = await req(searchUrl);
  console.log('Search Status:', searchRes.status, 'HTML len:', searchRes.body?.length);
  console.log('Search snippet:\n', searchRes.body?.substring(0, 500));

  const movieLinks = [...(searchRes.body || '').matchAll(/href=["'](movie-[^"']+)["']/g)].map((m) => m[1]);
  console.log('Movie links found:', movieLinks);

  if (movieLinks.length) {
    const moviePageUrl = `https://fzmovies.net/${movieLinks[0]}`;
    console.log('\nFetching movie page:', moviePageUrl);
    const movieRes = await req(moviePageUrl);
    console.log('Movie page status:', movieRes.status);

    const downloadLinks = [...(movieRes.body || '').matchAll(/href=["'](download\.php\?[^"']+)["']/g)].map((m) => m[1]);
    console.log('Download links on movie page:', downloadLinks);

    if (downloadLinks.length) {
      const dlUrl = `https://fzmovies.net/${downloadLinks[0]}`;
      console.log('\nFetching download page:', dlUrl);
      const dlRes = await req(dlUrl);
      console.log('Download page status:', dlRes.status);
      console.log('Download page snippet:\n', dlRes.body?.substring(0, 500));

      const finalLinks = [...(dlRes.body || '').matchAll(/href=["'](https?:\/\/[^"']+\.mp4[^"']*)["']/g)].map((m) => m[1]);
      console.log('\nFINAL DIRECT STREAM LINKS:');
      for (const fl of finalLinks) {
        console.log('  ->', fl);
      }
    }
  }
}

main();
