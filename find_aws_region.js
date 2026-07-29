const https = require('https');

// Simple IPv6 checker: is IP in CIDR?
// For our case, we can just do a prefix match by converting IPv6 to binary or hex
function ipv6ToHex(ip) {
  // expand double colon
  let full = ip;
  if (ip.includes('::')) {
    const parts = ip.split('::');
    const left = parts[0].split(':').filter(x => x !== '');
    const right = parts[1].split(':').filter(x => x !== '');
    const missing = 8 - (left.length + right.length);
    const middle = Array(missing).fill('0');
    full = [...left, ...middle, ...right].join(':');
  }
  return full.split(':').map(x => x.padStart(4, '0')).join('');
}

function matchCidr(ip, cidr) {
  const [cidrIp, bitsStr] = cidr.split('/');
  const bits = parseInt(bitsStr, 10);
  const ipHex = ipv6ToHex(ip);
  const cidrHex = ipv6ToHex(cidrIp);
  
  // compare the first 'bits' bits
  const charsToCompare = Math.ceil(bits / 4);
  const maskBits = bits % 4;
  
  if (ipHex.substring(0, charsToCompare - 1) !== cidrHex.substring(0, charsToCompare - 1)) {
    return false;
  }
  
  if (maskBits === 0) {
    return ipHex[charsToCompare - 1] === cidrHex[charsToCompare - 1];
  }
  
  // compare last char using bitwise mask
  const val1 = parseInt(ipHex[charsToCompare - 1], 16);
  const val2 = parseInt(cidrHex[charsToCompare - 1], 16);
  const mask = (0xF << (4 - maskBits)) & 0xF;
  
  return (val1 & mask) === (val2 & mask);
}

https.get('https://ip-ranges.amazonaws.com/ip-ranges.json', (res) => {
  let data = '';
  res.on('data', chunk => { data += chunk; });
  res.on('end', () => {
    try {
      const obj = JSON.parse(data);
      const targetIp = '2406:da1c:61c:d600:9748:2822:db4a:f992';
      console.log('Searching for target IP:', targetIp);
      
      const matches = [];
      for (const item of obj.ipv6_prefixes) {
        if (matchCidr(targetIp, item.ipv6_prefix)) {
          matches.push(item);
        }
      }
      
      console.log('Matches found:', JSON.stringify(matches, null, 2));
    } catch (err) {
      console.error('Error parsing AWS IP ranges:', err);
    }
  });
}).on('error', err => {
  console.error('Fetch failed:', err);
});
