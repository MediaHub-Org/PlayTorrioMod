const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

function inspectRange(start, length = 10000) {
    console.log(`\n=================== RANGE: ${start} - ${start + length} ===================`);
    console.log(code.substring(start, start + length));
}

// Around pos 1340000
inspectRange(1340000, 15000);
