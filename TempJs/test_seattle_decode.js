const https = require('https');
const { URL } = require('url');

function testSeattleDirect() {
    return new Promise((resolve) => {
        // Let's test with Seattle (4K server!)
        const streamUrl = `https://movienig.ht/api/stream/v1/movie/1084199?imdbId=tt11378946&title=Obsession&server=seattle&only=1`;
        console.log(`\n=================== Deep Testing Seattle ===================`);
        console.log(`URL: ${streamUrl}`);

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
            console.log('Status:', res.statusCode);
            res.on('data', chunk => {
                const str = chunk.toString();
                console.log('--- Event Data ---');
                console.log(str);

                // Decode base64 URL if present
                const match = str.match(/https:\/\/proxy\.scrapeequalsgayporn\.st\/api\/stream\/proxy\?u=([a-zA-Z0-9_-]+)/);
                if (match && match[1]) {
                    try {
                        const b64 = match[1].replace(/-/g, '+').replace(/_/g, '/');
                        const decoded = Buffer.from(b64, 'base64').toString('utf8');
                        console.log('\n[DECODED UPSTREAM HLS URL]:');
                        console.log(decoded);
                    } catch (e) {
                        console.error('Failed to decode base64:', e);
                    }
                }
            });
            res.on('end', () => resolve());
        });
        req.on('error', err => {
            console.error('Error:', err);
            resolve();
        });
        req.end();
    });
}

testSeattleDirect();
