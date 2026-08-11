const https = require('https');
const http = require('http');
const { URL } = require('url');

function fetchServerStream(serverName) {
    return new Promise((resolve) => {
        const streamUrl = `https://movienig.ht/api/stream/v1/movie/1084199?imdbId=tt11378946&title=Obsession&server=${serverName}&only=1`;
        console.log(`\n=================== Testing Server: "${serverName}" ===================`);
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
                console.log('--- Event Data ---');
                console.log(chunk.toString());
            });
            res.on('end', () => {
                console.log(`Finished ${serverName}`);
                resolve();
            });
        });
        req.on('error', err => {
            console.error(`Error on ${serverName}:`, err.message);
            resolve();
        });
        req.end();
    });
}

async function testAllServers() {
    const servers = [
        'seattle',
        'dallas',
        'tucson',
        'salem',
        'vixsrc-1', // Newport Beach
        'austin',
        'boston',
        'orlando',
        'atlanta',
        'phoenix',
        'nashville',
        'california',
        'helena'
    ];

    for (const server of servers) {
        await fetchServerStream(server);
    }
}

testAllServers();
