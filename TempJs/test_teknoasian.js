const https = require('https');

function req(targetUrl) {
  return new Promise((resolve) => {
    https.get(
      targetUrl,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          Referer: 'https://downloadeverythingfromeverywhere.com/',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
      }
    );
  });
}

async function main() {
  const url = 'https://teknoasian.com/?ht=Uj3BbvnpdxitFrMfwxrvKADFCZoRxEY9TonIgOBoybzV6GDCzbrpF6wV3qPekuYeaHl3MTljc0I1OFMyOVY2MnZPT0lsQ042dEdPN2cwU2l3QVpwK1lYRHdhK3JMajNLdkFTK05WekUyWnBRVVQyNXhzeVFCZU51eE5Lck55UG05RFR1YXc9PQ%3D%3D';
  const res = await req(url);
  console.log('Teknoasian Status:', res.status, 'HTML len:', res.body.length);
  console.log('Location:', res.headers.location);
  console.log('Snippet:\n', res.body.substring(0, 800));

  const links = [...res.body.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  console.log('Links:', links);
}

main();
