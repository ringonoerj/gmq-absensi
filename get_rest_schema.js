const https = require('https');
const fs = require('fs');

const options = {
  hostname: 'dqrymuvfkxtzzltlqzhw.supabase.co',
  path: '/rest/v1/',
  headers: {
    'apikey': 'sb_publishable_n1xS13CZ4_-liMGwg5L5hA_VckZygrY',
    'Authorization': 'Bearer sb_publishable_n1xS13CZ4_-liMGwg5L5hA_VckZygrY'
  }
};

https.get(options, (res) => {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    try {
      const schema = JSON.parse(data);
      fs.writeFileSync('db_schema.json', JSON.stringify(schema, null, 2));
      console.log('Successfully wrote schema to db_schema.json');
      
      // Print tables and their columns
      console.log('\nTables found:');
      for (const [path, info] of Object.entries(schema.definitions)) {
        console.log(`- ${path}:`);
        for (const [colName, colInfo] of Object.entries(info.properties)) {
          console.log(`  * ${colName} (${colInfo.type})`);
        }
      }
    } catch (e) {
      console.error('Error parsing response:', e);
      console.log('Raw output length:', data.length);
    }
  });
}).on('error', (err) => {
  console.error('Request error:', err);
});
