const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

function findContext(pattern, contextLen = 500) {
    console.log(`\n=================== PATTERN: ${pattern} ===================`);
    let idx = 0;
    let count = 0;
    while ((idx = code.indexOf(pattern, idx)) !== -1) {
        count++;
        const start = Math.max(0, idx - 200);
        const end = Math.min(code.length, idx + pattern.length + contextLen);
        console.log(`--- Match ${count} at ${idx} ---`);
        console.log(code.substring(start, end).replace(/\s+/g, ' '));
        idx += pattern.length;
        if (count >= 5) break;
    }
}

findContext('Seattle');
findContext('serverOptions');
findContext('provider');
findContext('cQ=');
findContext('VIDEASY_BASE');
