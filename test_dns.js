const dns = require('dns');

function checkDns(host) {
  dns.resolve(host, (err, addresses) => {
    if (err) {
      console.log(`${host} resolution failed: ${err.message}`);
    } else {
      console.log(`${host} resolved to:`, addresses);
    }
  });
}

checkDns('aws-0-ap-southeast-1.pooler.supabase.com');
checkDns('aws-ap-southeast-1.pooler.supabase.com');
checkDns('aws-0-ap-southeast-2.pooler.supabase.com');
checkDns('aws-ap-southeast-2.pooler.supabase.com');
