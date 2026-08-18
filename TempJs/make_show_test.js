const fs = require('fs');

let code = fs.readFileSync('TempJs/downloadeverything_master_resolver.js', 'utf8');

// Test TV show: House of the Dragon S01E01 (TMDB 94997)
code = code.replace(/async function test\(\) \{[\s\S]*?test\(\);/, `
async function testShow() {
  console.log('=== TESTING TV SHOW: HOUSE OF THE DRAGON S01E01 ===\\n');
  const streams = await resolveAllStreams({
    mode: 'series',
    title: 'House of the Dragon',
    year: '2022',
    tmdb_id: 94997,
    imdb_id: 'tt11198330',
    season: 1,
    episode: 1,
  });

  console.log('\\nSample TV Stream Objects:\\n', JSON.stringify(streams.slice(0, 5), null, 2));
}

testShow();
`);

fs.writeFileSync('TempJs/test_show_master_resolver.js', code);
console.log('Saved TempJs/test_show_master_resolver.js');
