const dns = require('dns');

dns.resolve6('db.dqrymuvfkxtzzltlqzhw.supabase.co', (err, addresses) => {
  if (err) {
    console.error('db.dqrymuvfkxtzzltlqzhw.supabase.co failed:', err.message);
  } else {
    console.log('db.dqrymuvfkxtzzltlqzhw.supabase.co AAAA:', addresses);
  }
});

dns.resolve6('dqrymuvfkxtzzltlqzhw.supabase.co', (err, addresses) => {
  if (err) {
    console.error('dqrymuvfkxtzzltlqzhw.supabase.co failed:', err.message);
  } else {
    console.log('dqrymuvfkxtzzltlqzhw.supabase.co AAAA:', addresses);
  }
});
