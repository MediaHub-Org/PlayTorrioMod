const https = require('https');

function postForm(targetUrl, hqValue) {
  return new Promise((resolve) => {
    const postData = `hq=${encodeURIComponent(hqValue)}`;
    const req = https.request(
      targetUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(postData),
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: targetUrl,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
    req.write(postData);
    req.end();
  });
}

async function main() {
  const hq = '3vljQlU9jsDXU4+E9ZU6w3kSe3cdVqD1rs5X7JErfYNhZvBAVDz+yIo6riW1pL/udDFpaEI3MFgyRDA3WEFsQ1ZpeVpudlc5WmlEWnFLRDVpcGtjcGRQNThCRUx4SWN4b1o1enFZeEZiNjgraEVBNXc4YlNlTDFFbzJINVFTcERYU083bHVSZVRoQXZSNlJtTm1sajkycnZ3bXFVL3FJY0E5ZnZxcml1T21NeE15L0RmUzJUcHBORW1iYlBFYnJwUWNEMHhuTm9ZLzhxVDlUOGxUYlA0SG5pSkl2N0ttdkRJOGlDNEN4blhka3FDWnFYNXFSR0pFOUR5aWxMNEo1SFM2Z29pMUhuVm5nNW5Mc2MyLzQ5UUJLNFhxNkRQdyttdWZkbnRNZ2hDcEpqNHNoQkFxNzBNb3Z2NDlEOXVOK0lGS1lIK1VveURjdW5uVCtMakw1MFgzMEVmbDRPQnB4ZTQ2ZjU0NDBEV2lZeXQ2SE45YzNTMlRQSGJiOWx1VjM2ZEl4QlUvSmUrT05FSjB4Q04wZkFldVJydFVoU0F4VWRqdjNXQmpydzdnZGhBc3VFTnE3QTlleDRjWEN1VTZBNjBpRmVaMW96UHZCOGR1QlpUOG5Pb3BLSjRjZz0=';
  const res = await postForm('https://teknoasian.com/', hq);
  console.log('Status:', res.status, 'Location:', res.headers.location);
  console.log('Body length:', res.body.length);
  console.log('Snippet:\n', res.body.substring(0, 500));

  const directLinks = [...res.body.matchAll(/href=["']([^"']+)["']/g)].map((m) => m[1]);
  console.log('Direct destination links:', directLinks);
}

main();
