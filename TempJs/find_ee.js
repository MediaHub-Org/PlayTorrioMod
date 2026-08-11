const fs = require('fs');
const path = require('path');

const jsPath = path.join(__dirname, 'movienight_study', 'index-ChgCT5F3.js');
const code = fs.readFileSync(jsPath, 'utf8');

// We want to inspect around pos 1347000 to find where function `ee` is defined or called
const pos = 1347000;
console.log("=== CODE AROUND 1345000 - 1347500 ===");
console.log(code.substring(1344000, 1347500));
