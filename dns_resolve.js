const dns = require('dns');

function resolve(host) {
  console.log(`Resolving ${host}...`);
  dns.resolveAny(host, (err, ret) => {
    if (err) {
      console.error(`Error resolving ${host}:`, err);
    } else {
      console.log(`Results for ${host}:`, JSON.stringify(ret, null, 2));
    }
  });
}

resolve('dqrymuvfkxtzzltlqzhw.supabase.co');
resolve('db.dqrymuvfkxtzzltlqzhw.supabase.co');
resolve('aws-0-ap-southeast-1.pooler.supabase.com');
