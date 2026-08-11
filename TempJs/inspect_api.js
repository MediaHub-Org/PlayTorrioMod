const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

console.log("Code length:", code.length);

// Search for server resolution logic, API calls, or provider declarations
const searchTerms = ['/api/', 'server', 'provider', 'Seattle', 'Dallas', 'Tucson', 'Salem', 'Newport', 'vidsrc', 'embed', 'stream', 'sources'];

for (const term of searchTerms) {
    let idx = 0;
    let count = 0;
    console.log(`\n=== Term: "${term}" ===`);
    while ((idx = code.indexOf(term, idx)) !== -1) {
        count++;
        const snippet = code.substring(Math.max(0, idx - 150), Math.min(code.length, idx + 250)).replace(/\s+/g, ' ');
        console.log(`[${idx}] ${snippet}`);
        idx += term.length;
        if (count >= 5) break;
    }
}
