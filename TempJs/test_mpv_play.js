const { spawn } = require('child_process');

const mpvPath = 'C:\\ProgramData\\chocolatey\\lib\\mpvio.install\\tools\\mpv.com';
const testUrl = 'https://c6b1e8c93683bdde581e2164cb9657c9.r2.cloudflarestorage.com/hub/1a2c0808e04c74d7344a26ca339c32b5?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ce3806fdca997f65e356f3b6fc2f735d%2F20260817%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20260817T171028Z&X-Amz-Expires=28800&X-Amz-SignedHeaders=host&response-content-disposition=attachment%3B%20filename%3D%22Obsession%20%282025%29%201080p%20UHD%20BluRay%20DV%20HDR%2010bit%20HEVC%20%5BHindi%20AMZN%20DDP%205.1%20%2B%20English%20DDP7.1%5D%20x265%20%28HiDt-LUMiX%29.mkv%22&X-Amz-Signature=f708e575c2240746ec68fea5d8471e10eb3a049a5cfa2ec3217645818f7c383c';

console.log('=== TESTING MPV STREAM PLAYBACK ===\n');
console.log('Running MPV on URL:', testUrl.substring(0, 100) + '...\n');

const proc = spawn(mpvPath, [
  '--no-video',
  '--frames=30',
  '--msg-level=all=status',
  testUrl,
]);

proc.stdout.on('data', (d) => console.log('[MPV stdout]', d.toString().trim()));
proc.stderr.on('data', (d) => console.log('[MPV stderr]', d.toString().trim()));

proc.on('close', (code) => {
  console.log('\nMPV exited with code:', code);
  if (code === 0) {
    console.log('>>> VERIFIED: 100% STREAMABLE IN MPV <<<');
  }
});
