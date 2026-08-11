const https = require('https');
const http = require('http');
const { URL } = require('url');

function fetchJson(urlStr, headers = {}) {
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
                'Accept': 'application/json, text/plain, */*',
                'Referer': 'https://movienig.ht/',
                'Origin': 'https://movienig.ht',
                ...headers
            }
        };

        const req = mod.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, data: JSON.parse(data), raw: data, headers: res.headers });
                } catch (e) {
                    resolve({ status: res.statusCode, data: null, raw: data, headers: res.headers });
                }
            });
        });
        req.on('error', err => reject(err));
        req.end();
    });
}

async function testApi() {
    console.log('=== Testing https://movienig.ht/api/servers ===');
    const serversRes = await fetchJson('https://movienig.ht/api/servers');
    console.log('Status:', serversRes.status);
    console.log('Servers payload:', JSON.stringify(serversRes.data, null, 2));

    // tt11378946 TMDb ID: let's test fetching stream for movie
    // Let's test with TMDb ID (e.g. 1084199 or tt11378946)
    const tmdbId = '1084199'; // or tt11378946
    const streamUrl = `https://movienig.ht/api/stream/v1/movie/${tmdbId}?imdbId=tt11378946&title=Obsession`;

    console.log(`\n=== Opening EventSource / SSE connection to ${streamUrl} ===`);
    const u = new URL(streamUrl);
    const options = {
        hostname: u.hostname,
        port: 443,
        path: u.pathname + u.search,
        method: 'GET',
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/event-stream',
            'Referer': 'https://movienig.ht/',
            'Origin': 'https://movienig.ht'
        }
    };

    const req = https.request(options, (res) => {
        console.log('SSE Status:', res.statusCode);
        console.log('SSE Headers:', res.headers);
        res.on('data', chunk => {
            console.log('--- SSE Chunk Received ---');
            console.log(chunk.toString());
        });
        res.on('end', () => console.log('=== SSE Stream Closed ==='));
    });
    req.on('error', err => console.error('SSE Error:', err));
    req.end();
}

testApi();
