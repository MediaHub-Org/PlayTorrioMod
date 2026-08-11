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
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                ...headers
            }
        };

        const req = mod.request(options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                const loc = new URL(res.headers.location, urlStr).toString();
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
    console.log('--- Fetching https://movienig.ht/watch/movie/tt11378946 ---');
    const res = await fetchUrl('https://movienig.ht/watch/movie/tt11378946');
    console.log('Status:', res.statusCode);
    console.log('Body snippet:');
    console.log(res.body.substring(0, 1500));
}

run();
