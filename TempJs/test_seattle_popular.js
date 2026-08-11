const https = require('https');
const { URL } = require('url');

function testSeattleWithTitles(tmdbId, title, year, imdbId) {
    return new Promise((resolve) => {
        const streamUrl = `https://movienig.ht/api/stream/v1/movie/${tmdbId}?imdbId=${imdbId}&title=${encodeURIComponent(title)}&year=${year}&server=seattle&only=1`;
        console.log(`\n=================== Testing Seattle: "${title}" (${year}) ===================`);
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
    // Test popular titles on Seattle
    await testSeattleWithTitles('27205', 'Inception', 2010, 'tt1375666');
    await testSeattleWithTitles('157336', 'Interstellar', 2014, 'tt0816692');
    await testSeattleWithTitles('550', 'Fight Club', 1999, 'tt0137523');
}

run();
