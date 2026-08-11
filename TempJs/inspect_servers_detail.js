const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

function findOccurrences(query, num = 5) {
    console.log(`\n=================== SEARCH: "${query}" ===================`);
    let idx = 0;
    let count = 0;
    while ((idx = code.indexOf(query, idx)) !== -1) {
        count++;
        const snippet = code.substring(Math.max(0, idx - 200), Math.min(code.length, idx + query.length + 300)).replace(/\s+/g, ' ');
        console.log(`[${idx}] ${snippet}`);
        idx += query.length;
        if (count >= num) break;
    }
}

findOccurrences('serverOptions');
findOccurrences('server');
findOccurrences('provider');
findOccurrences('vsembed');
findOccurrences('vidlink');
