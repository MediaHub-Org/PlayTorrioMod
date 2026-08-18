const fs = require('fs');

let code = fs.readFileSync('TempJs/test_clicknupload_step3.js', 'utf8');

code = code.replace("console.log('Step 3 status:', res3.status, 'Location:', res3.headers.location);", "console.log('Step 3 status:', res3.status, 'Location:', res3.headers.location); require('fs').writeFileSync('TempJs/clickn_step3.html', res3.body);");

fs.writeFileSync('TempJs/test_clicknupload_step3.js', code);

const { execSync } = require('child_process');
execSync('node TempJs/test_clicknupload_step3.js', { stdio: 'inherit' });

const step3Html = fs.readFileSync('TempJs/clickn_step3.html', 'utf8');

// Find all buttons, links, or window.open in step 3
console.log('\n--- Step 3 Inspection ---');
const btnMatch = [...step3Html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)];
for (const bm of btnMatch) {
  if (bm[1].includes('http') && !bm[1].includes('clicknupload.click/nm8ty9956ia8')) {
    console.log(`Button: "${bm[2].replace(/<[^>]+>/g, '').trim()}" -> ${bm[1]}`);
  }
}

// Search for onClick or download_link
const scriptLinks = [...step3Html.matchAll(/https?:\/\/[a-zA-Z0-9.\-_:\/]+\.(?:mkv|mp4|avi|webm)[^"'\s<>]*/gi)].map((m) => m[0]);
console.log('\nDirect media links in Step 3:', scriptLinks);
