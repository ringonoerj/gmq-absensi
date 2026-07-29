const dns = require('dns');

dns.reverse('2406:da1c:61c:d600:9748:2822:db4a:f992', (err, hostnames) => {
  if (err) {
    console.error('Reverse DNS failed:', err.message);
  } else {
    console.log('Hostnames:', hostnames);
  }
});
