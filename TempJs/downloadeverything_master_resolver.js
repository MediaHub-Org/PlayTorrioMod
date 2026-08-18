const https = require('https');
const http = require('http');

function httpGet(targetUrl, headers = {}) {
  return new Promise((resolve) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const req = client.request(
      targetUrl,
      {
        method: 'GET',
        rejectUnauthorized: false,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          ...headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    req.on('error', (err) => resolve({ error: err.message }));
    req.setTimeout(10000, () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });
    req.end();
  });
}

function httpPost(targetUrl, bodyData, headers = {}) {
  return new Promise((resolve) => {
    const urlObj = new URL(targetUrl);
    const client = urlObj.protocol === 'https:' ? https : http;
    const bodyStr = typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData);

    const req = client.request(
      targetUrl,
      {
        method: 'POST',
        rejectUnauthorized: false,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          ...(typeof bodyData === 'string' ? { 'Content-Type': 'application/x-www-form-urlencoded' } : { 'Content-Type': 'application/json' }),
          'Content-Length': Buffer.byteLength(bodyStr),
          ...headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    req.on('error', (err) => resolve({ error: err.message }));
    req.setTimeout(10000, () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });
    req.write(bodyStr);
    req.end();
  });
}

// 1. Pixeldrain Extractor
function resolvePixeldrain(rawUrl) {
  const m = rawUrl.match(/pixeldrain\.(?:dev|com)\/(?:u|l)\/([a-zA-Z0-9_-]+)/);
  if (!m) return null;
  return `https://pixeldrain.com/api/file/${m[1]}`;
}

// 2. HubCloud Extractor
async function resolveHubcloud(rawUrl) {
  try {
    let pageRes = await httpGet(rawUrl, { Referer: 'https://downloadeverythingfromeverywhere.com/' });
    if (pageRes.status >= 300 && pageRes.status < 400 && pageRes.headers?.location) {
      pageRes = await httpGet(pageRes.headers.location, { Referer: rawUrl });
    }

    const html = pageRes.body || '';
    const hubPhpMatch = html.match(/https?:\/\/[^\s"'<>]+\/hubcloud\.php\?[^\s"'<>]+/);
    if (hubPhpMatch) {
      const phpRes = await httpGet(hubPhpMatch[0], { Referer: rawUrl });
      const phpBody = phpRes.body || '';

      // Check for Cloudflare R2 / S3 signed video link
      const r2Match = phpBody.match(/https?:\/\/[a-zA-Z0-9.\-_]+\.r2\.cloudflarestorage\.com\/[^\s"'<>]+/);
      if (r2Match) {
        return r2Match[0].replace(/&amp;/g, '&');
      }

      // Check for Pixel mirror
      const pixelMatch = phpBody.match(/https?:\/\/pixel\.hubcloud\.[a-z]+\/\?id=([^\s"'<>]+)/);
      if (pixelMatch) {
        return pixelMatch[0];
      }
    }
  } catch (e) {}
  return null;
}

// 3. Moviebox Resolver
function resolveMoviebox(rawUrl) {
  if (rawUrl.includes('hakunaymatata.com')) {
    return rawUrl;
  }
  return null;
}

// 4. ClicknUpload Resolver
async function resolveClicknupload(rawUrl) {
  try {
    const res1 = await httpGet(rawUrl, { Referer: 'https://downloadeverythingfromeverywhere.com/' });
    const formMatch = res1.body?.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
    if (!formMatch) return null;

    const inputs = [...formMatch[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
    const params = new URLSearchParams();
    for (const im of inputs) params.append(im[1], im[2]);
    if (!params.has('method_free')) params.append('method_free', 'Slow Download');

    const res2 = await httpPost(rawUrl, params.toString(), { Referer: rawUrl });
    const formMatch2 = res2.body?.match(/<form[^>]+method=["']POST["'][^>]*>([\s\S]*?)<\/form>/i);
    if (!formMatch2) return null;

    const inputs2 = [...formMatch2[1].matchAll(/<input[^>]+name=["']([^"']+)["'][^>]+value=["']([^"']*)["']/gi)];
    const params2 = new URLSearchParams();
    for (const im of inputs2) params2.append(im[1], im[2]);
    params2.append('down_script', '1');

    await new Promise((r) => setTimeout(r, 4500));

    const res3 = await httpPost(rawUrl, params2.toString(), { Referer: rawUrl });
    const directMatch = res3.body?.match(/https?:\/\/[a-zA-Z0-9.\-_:]+\/d\/[a-zA-Z0-9_\-\/]+/i) || res3.body?.match(/href=["'](https?:\/\/[^"']+\.(?:mkv|mp4)[^"']*)["']/i);
    if (directMatch) return directMatch[1] || directMatch[0];
  } catch (e) {}
  return null;
}

async function streamSlaveMaster(payload) {
  console.log('=== SCRAPING DOWNLOADEVERYTHING ===\nPayload:', payload);

  return new Promise((resolve, reject) => {
    const bodyStr = JSON.stringify(payload);
    const options = {
      hostname: 'slave.downloadeverythingfromeverywhere.com',
      port: 443,
      path: '/',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        Origin: 'https://downloadeverythingfromeverywhere.com',
        Referer: 'https://downloadeverythingfromeverywhere.com/',
      },
    };

    const rawHits = [];

    const req = https.request(options, (res) => {
      let buffer = '';
      res.on('data', (chunk) => {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop();
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;
          try {
            const parsed = JSON.parse(trimmed);
            if (parsed.t === 'hit' && parsed.links) {
              rawHits.push(...parsed.links.map((l) => ({ site: parsed.site, ...l })));
            }
          } catch (e) {}
        }
      });

      res.on('end', () => {
        if (buffer.trim()) {
          try {
            const parsed = JSON.parse(buffer.trim());
            if (parsed.t === 'hit' && parsed.links) {
              rawHits.push(...parsed.links.map((l) => ({ site: parsed.site, ...l })));
            }
          } catch (e) {}
        }
        resolve(rawHits);
      });
    });

    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

async function resolveAllStreams(payload) {
  const rawItems = await streamSlaveMaster(payload);
  console.log(`\nRetrieved ${rawItems.length} total raw links from slave. Resolving and extracting streamable links...\n`);

  const playableStreams = [];

  for (const item of rawItems) {
    const rawUrl = item.url || '';

    // Skip unstreamable / blocked hosts
    if (
      rawUrl.includes('111477.xyz') ||
      rawUrl.includes('vadapav.mov') ||
      rawUrl.includes('driveseed.org') ||
      rawUrl.includes('megaup.net') ||
      rawUrl.includes('new3.gdflix.io') ||
      rawUrl.includes('rapidrar.cr')
    ) {
      continue;
    }

    let streamUrl = null;
    let provider = item.site || 'DownloadEverything';

    // 1. Moviebox
    if (rawUrl.includes('hakunaymatata.com')) {
      streamUrl = resolveMoviebox(rawUrl);
      provider = 'Moviebox';
    }
    // 2. Pixeldrain
    else if (rawUrl.includes('pixeldrain.dev') || rawUrl.includes('pixeldrain.com')) {
      streamUrl = resolvePixeldrain(rawUrl);
      provider = 'Pixeldrain';
    }
    // 3. HubCloud
    else if (rawUrl.includes('hubcloud.') || rawUrl.includes('vcloud.zip')) {
      streamUrl = await resolveHubcloud(rawUrl);
      provider = 'HubCloud';
    }
    // 4. ClicknUpload
    else if (rawUrl.includes('clicknupload.')) {
      streamUrl = await resolveClicknupload(rawUrl);
      provider = 'ClicknUpload';
    }

    if (streamUrl) {
      const quality = (item.tags || []).find((t) => /2160p|4k|1080p|720p|480p/i.test(t)) || '1080p';
      const name = item.name || item.release || payload.title;

      playableStreams.push({
        name: `[${provider}] ${name} (${quality})`,
        url: streamUrl,
        quality: quality,
        tags: item.tags || [],
        site: item.site,
      });

      console.log(`[+] PLAYABLE STREAM: [${provider}] ${quality} -> ${streamUrl.substring(0, 90)}...`);
    }
  }

  console.log(`\n========================================`);
  console.log(`TOTAL VERIFIED PLAYABLE STREAMS: ${playableStreams.length}`);
  console.log(`========================================\n`);
  return playableStreams;
}

async function test() {
  // Test Movie: Obsession (2026)
  const streams = await resolveAllStreams({
    mode: 'movie',
    title: 'Obsession',
    year: '2026',
    tmdb_id: 1339713,
    imdb_id: 'tt37287335',
  });

  console.log('Sample Stream Objects:\n', JSON.stringify(streams.slice(0, 5), null, 2));
}

test();
