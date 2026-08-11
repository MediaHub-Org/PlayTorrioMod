const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

// Print around index 1349000 to see how server options are loaded or mapped
const start = 1347000;
const end = 1352000;

console.log("=== CODE SNIPPET (1347000 - 1352000) ===");
console.log(code.substring(start, end));
