const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

function findKeywords(keywords) {
    for (const kw of keywords) {
        console.log(`\n=================== KEYWORD: "${kw}" ===================`);
        let idx = 0;
        let count = 0;
        while ((idx = code.indexOf(kw, idx)) !== -1) {
            count++;
            const snippet = code.substring(Math.max(0, idx - 150), Math.min(code.length, idx + kw.length + 250)).replace(/\s+/g, ' ');
            console.log(`[${idx}] ${snippet}`);
            idx += kw.length;
            if (count >= 5) break;
        }
    }
}

findKeywords(['/api/watch', '/api/sources', '/api/stream', 'fetchSource', 'resolveSource', 'playSource', 'iframe', 'vsembed', 'vidlink']);
