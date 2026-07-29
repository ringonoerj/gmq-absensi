const https = require('https');

https.get('https://ip-ranges.amazonaws.com/ip-ranges.json', (res) => {
  let data = '';
  res.on('data', chunk => { data += chunk; });
  res.on('end', () => {
    const obj = JSON.parse(data);
    const results = [];
    obj.ipv6_prefixes.forEach(item => {
      if (item.ipv6_prefix.startsWith('2406:da1c')) {
        results.push(item);
      }
    });
    console.log(JSON.stringify(results, null, 2));
  });
});
