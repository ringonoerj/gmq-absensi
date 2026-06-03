const dns = require('dns');

dns.resolve6('db.dqrymuvfkxtzzltlqzhw.supabase.co', (err, addresses) => {
  if (err) {
    console.error('Error resolving AAAA records:', err);
  } else {
    console.log('AAAA records (IPv6 addresses):', addresses);
  }
});
