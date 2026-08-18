const fs = require('fs');

const html = fs.readFileSync('TempJs/clickn_step3.html', 'utf8');

// Find all elements with class or id containing download
const matches = [...html.matchAll(/<(?:a|button|form|input)[^>]+(?:download|btn|direct)[^>]*>([\s\S]*?)<\/(?:a|button|form)>/gi)];
console.log(`Found ${matches.length} download elements:`);
for (const m of matches) {
  console.log(m[0].substring(0, 300));
}

// Also check any script variables or window.open
const scriptMatches = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
for (const s of scriptMatches) {
  if (s.includes('http') || s.includes('download') || s.includes('btn')) {
    console.log('\nScript snippet:\n', s.substring(0, 500));
  }
}
