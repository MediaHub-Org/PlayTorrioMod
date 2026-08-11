const https = require('https');
const { URL } = require('url');

function testSeriesServer(tmdbId, season, episode, imdbId, serverName) {
    return new Promise((resolve) => {
        const streamUrl = `https://movienig.ht/api/stream/v1/tv/${tmdbId}/${season}/${episode}?imdbId=${imdbId}&title=Test&server=${serverName}&only=1`;
        console.log(`\n=================== Testing TV Series (${serverName}) ===================`);
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

async function run() {
    // Test Breaking Bad S1E1: TMDb 1396, IMDb tt0903747
    await testSeriesServer('1396', 1, 1, 'tt0903747', 'dallas');
    await testSeriesServer('1396', 1, 1, 'tt0903747', 'seattle');
    await testSeriesServer('1396', 1, 1, 'tt0903747', 'austin');
}

run();
