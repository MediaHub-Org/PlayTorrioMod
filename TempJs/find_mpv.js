const fs = require('fs');
const { execSync } = require('child_process');

console.log('=== FINDING MPV EXECUTABLE ===\n');

const paths = [
  'c:\\Users\\Ayman\\Desktop\\PlayTorrioV3\\Player\\mpv\\mpv.exe',
  'c:\\Users\\Ayman\\Desktop\\PlayTorrioV3\\Player\\mpv.exe',
  'c:\\Users\\Ayman\\Desktop\\PlayTorrioV3\\bin\\mpv.exe',
  'mpv.exe',
];

let foundMpv = null;
for (const p of paths) {
  if (fs.existsSync(p)) {
    console.log('Found MPV at:', p);
    foundMpv = p;
    break;
  }
}

if (!foundMpv) {
  try {
    const which = execSync('where mpv', { encoding: 'utf8' });
    console.log('where mpv:', which.trim());
    foundMpv = which.trim().split('\n')[0].trim();
  } catch (e) {}
}

console.log('Using MPV path:', foundMpv);
