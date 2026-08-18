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

async function studyHubcloud(hubUrl) {
  console.log(`\n========================================`);
  console.log(`Studying HubCloud: ${hubUrl}`);
  console.log(`========================================`);

  try {
    const page1 = await req(hubUrl);
    console.log('Step 1 status:', page1.status, 'Location:', page1.headers.location);

    let currentHtml = page1.body;
    if (page1.status >= 300 && page1.status < 400 && page1.headers.location) {
      console.log('Following 302 to:', page1.headers.location);
      const resRedirect = await req(page1.headers.location, { Referer: hubUrl });
      currentHtml = resRedirect.body;
      console.log('Redirected page status:', resRedirect.status, 'HTML len:', currentHtml.length);
    }

    // Look for gamerxyt / hubcloud.php or download link
    const hubPhpMatch = currentHtml.match(/https?:\/\/[^\s"'<>]+\/hubcloud\.php\?[^\s"'<>]+/);
    if (hubPhpMatch) {
      console.log('\n[+] Found HubCloud token link:', hubPhpMatch[0]);
      const phpRes = await req(hubPhpMatch[0], { Referer: hubUrl });
      console.log('hubcloud.php status:', phpRes.status, 'len:', phpRes.body.length);
      console.log('hubcloud.php snippet:\n', phpRes.body.substring(0, 500));

      const downloadLinks = [...phpRes.body.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
      console.log('\nFinal links in hubcloud.php:');
      for (const dl of downloadLinks) {
        console.log('  ->', dl);
      }
    }

    // If there is a redirect or next page (e.g. /download?id=...)
    let nextStepUrl = null;
    if (btnMatches.length) nextStepUrl = btnMatches[0];
    else if (scriptMatches.length) nextStepUrl = scriptMatches[0];
    else {
      const dlLink = links.find((l) => l.includes('/download') || l.includes('link=') || l.includes('token='));
      if (dlLink) nextStepUrl = dlLink;
    }

    if (nextStepUrl) {
      if (nextStepUrl.startsWith('/')) {
        const u = new URL(hubUrl);
        nextStepUrl = `${u.protocol}//${u.host}${nextStepUrl}`;
      }
      console.log('\n-> Following Step 2 to:', nextStepUrl);
      const page2 = await req(nextStepUrl, { Referer: hubUrl });
      console.log('Step 2 status:', page2.status, 'len:', page2.body.length);

      // Search for final download / stream servers in page 2
      const finalLinks = [...page2.body.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
      console.log('Final stream links on Step 2:');
      for (const fl of finalLinks) {
        if (
          fl.includes('pixeldrain') ||
          fl.includes('buzzheavier') ||
          fl.includes('fastcloud') ||
          fl.includes('hubdrive') ||
          fl.includes('gofile') ||
          fl.includes('.mkv') ||
          fl.includes('.mp4') ||
          fl.includes('worker')
        ) {
          console.log(`  [+] Stream Server Link: ${fl}`);
        }
      }
    }
  } catch (e) {
    console.log('Error:', e.message);
  }
}

async function main() {
  const hubUrls = [
    'https://hubcloud.ist/drive/osibpfr23cggdsb',
    'https://hubcloud.cx/drive/draatra5aglaheu',
    'https://vcloud.zip/4eiuzvf4tzme8qe',
  ];

  for (const hu of hubUrls) {
    await studyHubcloud(hu);
  }
}

main();
