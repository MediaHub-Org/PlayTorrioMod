const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

function findSnippets(query, contextSize = 300) {
    console.log(`\n=================== SEARCH QUERY: "${query}" ===================`);
    let pos = 0;
    let count = 0;
    while ((pos = code.toLowerCase().indexOf(query.toLowerCase(), pos)) !== -1) {
        count++;
        const start = Math.max(0, pos - contextSize);
        const end = Math.min(code.length, pos + query.length + contextSize);
        console.log(`--- Match #${count} (at pos ${pos}) ---`);
        console.log(code.substring(start, end).replace(/\s+/g, ' '));
        pos += query.length;
        if (count >= 10) break;
    }
    if (count === 0) {
        console.log("No matches found.");
    }
}

findSnippets('seattle');
findSnippets('tucson');
findSnippets('salem');
findSnippets('dallas');
findSnippets('newport');
