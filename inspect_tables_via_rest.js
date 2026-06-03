const https = require('https');

const apiKey = 'sb_publishable_n1xS13CZ4_-liMGwg5L5hA_VckZygrY';
const tables = ['siswa', 'guru', 'kelas', 'unit_pendidikan', 'absensi', 'users', 'app_settings', 'insentif_guru'];

function fetchSample(table) {
  const options = {
    hostname: 'dqrymuvfkxtzzltlqzhw.supabase.co',
    path: `/rest/v1/${table}?limit=1`,
    headers: {
      'apikey': apiKey,
      'Authorization': `Bearer ${apiKey}`
    }
  };

  https.get(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      try {
        const rows = JSON.parse(data);
        console.log(`\nTable: ${table}`);
        if (rows.length > 0) {
          console.log('Columns:');
          Object.entries(rows[0]).forEach(([col, val]) => {
            console.log(`  - ${col} (${typeof val}): sample = ${JSON.stringify(val)}`);
          });
        } else {
          console.log('  (No records found)');
        }
      } catch (e) {
        console.error(`Error parsing table ${table}:`, e);
      }
    });
  }).on('error', (err) => {
    console.error(`Error fetching table ${table}:`, err);
  });
}

tables.forEach(fetchSample);
