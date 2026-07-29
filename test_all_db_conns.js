const { Client } = require('pg');

const combos = [
  {
    name: 'Combo 1: User postgres.[ref], Port 5432, No options',
    config: {
      host: 'aws-0-ap-southeast-2.pooler.supabase.com',
      port: 5432,
      database: 'postgres',
      user: 'postgres.dqrymuvfkxtzzltlqzhw',
      password: 'PindangAyam1!',
      ssl: { rejectUnauthorized: false }
    }
  },
  {
    name: 'Combo 2: User postgres.[ref], Port 6543, No options',
    config: {
      host: 'aws-0-ap-southeast-2.pooler.supabase.com',
      port: 6543,
      database: 'postgres',
      user: 'postgres.dqrymuvfkxtzzltlqzhw',
      password: 'PindangAyam1!',
      ssl: { rejectUnauthorized: false }
    }
  },
  {
    name: 'Combo 3: User postgres, Port 5432, Options project=[ref]',
    config: {
      connectionString: 'postgresql://postgres:PindangAyam1!@aws-0-ap-southeast-2.pooler.supabase.com:5432/postgres?options=project%3Ddqrymuvfkxtzzltlqzhw',
      ssl: { rejectUnauthorized: false }
    }
  },
  {
    name: 'Combo 4: User postgres, Port 6543, Options project=[ref]',
    config: {
      connectionString: 'postgresql://postgres:PindangAyam1!@aws-0-ap-southeast-2.pooler.supabase.com:6543/postgres?options=project%3Ddqrymuvfkxtzzltlqzhw',
      ssl: { rejectUnauthorized: false }
    }
  },
  {
    name: 'Combo 5: User postgres.[ref], Port 5432, Options project=[ref]',
    config: {
      connectionString: 'postgresql://postgres.dqrymuvfkxtzzltlqzhw:PindangAyam1!@aws-0-ap-southeast-2.pooler.supabase.com:5432/postgres?options=project%3Ddqrymuvfkxtzzltlqzhw',
      ssl: { rejectUnauthorized: false }
    }
  },
  {
    name: 'Combo 6: User postgres.[ref], Port 6543, Options project=[ref]',
    config: {
      connectionString: 'postgresql://postgres.dqrymuvfkxtzzltlqzhw:PindangAyam1!@aws-0-ap-southeast-2.pooler.supabase.com:6543/postgres?options=project%3Ddqrymuvfkxtzzltlqzhw',
      ssl: { rejectUnauthorized: false }
    }
  }
];

async function testCombo(combo) {
  console.log(`Testing: ${combo.name}`);
  const client = new Client(combo.config);
  try {
    await client.connect();
    console.log(`  -> SUCCESS! Connected successfully.`);
    const res = await client.query('SELECT current_user, version();');
    console.log(`  -> Query result:`, res.rows[0]);
    await client.end();
    return true;
  } catch (err) {
    console.log(`  -> FAILED: ${err.message}`);
    return false;
  }
}

async function main() {
  for (const combo of combos) {
    const ok = await testCombo(combo);
    if (ok) {
      console.log('Found working configuration! Exiting.');
      break;
    }
    console.log('--------------------------------------------');
  }
}

main();
