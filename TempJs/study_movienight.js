const fs = require('fs');
const https = require('https');
const http = require('http');
const path = require('path');
const { URL } = require('url');

function fetchUrl(urlStr, headers = {}) {
    return new Promise((resolve, reject) => {
        const u = new URL(urlStr);
        const mod = u.protocol === 'https:' ? https : http;
        const options = {
            hostname: u.hostname,
            port: u.port || (u.protocol === 'https:' ? 443 : 80),
            path: u.pathname + u.search,
            method: 'GET',
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                ...headers
            }
        };

        const req = mod.request(options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                const loc = new URL(res.headers.location, urlStr).toString();
                console.log(`Redirecting [${res.statusCode}] -> ${loc}`);
                return resolve(fetchUrl(loc, headers));
            }
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve({ statusCode: res.statusCode, headers: res.headers, body: data }));
        });
        req.on('error', err => reject(err));
        req.end();
    });
}

async function run() {
    console.log('--- Fetching https://movienig.ht/ ---');
    try {
        const res = await fetchUrl('https://movienig.ht/');
        console.log('Status:', res.statusCode);
        console.log('Body snippet (first 1000 chars):');
        console.log(res.body.substring(0, 1000));

        const outDir = path.join(__dirname, 'movienight_study');
        if (!fs.existsSync(outDir)) {
            fs.mkdirSync(outDir, { recursive: true });
        }
        fs.writeFileSync(path.join(outDir, 'home.html'), res.body);

        // Find scripts
        const scriptMatches = [...res.body.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)].map(m => m[1]);
        console.log('\nFound script tags:', scriptMatches);

        for (const sUrl of scriptMatches) {
            const fullUrl = new URL(sUrl, 'https://movienig.ht/').toString();
            console.log(`Fetching script: ${fullUrl}`);
            try {
                const sRes = await fetchUrl(fullUrl);
                const sName = path.basename(new URL(fullUrl).pathname) || 'script.js';
                fs.writeFileSync(path.join(outDir, sName), sRes.body);
                console.log(`Saved ${sName} (${sRes.body.length} bytes)`);

                // Check for keywords like seattle, tucson, salem, dallas, newport, source, embed, api, provider
                const keywords = ['seattle', 'tucson', 'salem', 'dallas', 'newport', 'provider', 'sources', 'embed', 'server'];
                for (const kw of keywords) {
                    const regex = new RegExp(`[a-zA-Z0-9_$-]*${kw}[a-zA-Z0-9_$-]*`, 'gi');
                    const matches = [...new Set(sRes.body.match(regex))].slice(0, 15);
                    if (matches.length > 0) {
                        console.log(`  [${sName}] Found '${kw}' matches:`, matches.join(', '));
                    }
                }
            } catch (e) {
                console.error(`Failed to fetch script ${fullUrl}:`, e.message);
            }
        }
    } catch (e) {
        console.error('Fetch failed:', e);
    }
}

run();
