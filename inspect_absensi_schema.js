const { Client } = require('pg');

async function main() {
  const client = new Client({
    connectionString: 'postgresql://postgres.dqrymuvfkxtzzltlqzhw:PindangAyam1!@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?options=project%3Ddqrymuvfkxtzzltlqzhw',
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    console.log('Connected to DB!');
    
    // 1. Get columns of 'absensi'
    const colRes = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'absensi'
      ORDER BY ordinal_position;
    `);
    
    console.log('\n--- Columns in absensi table ---');
    colRes.rows.forEach(row => {
      console.log(`  - ${row.column_name} (${row.data_type}, nullable: ${row.is_nullable})`);
    });
    
    // 2. Get constraints of 'absensi'
    const conRes = await client.query(`
      SELECT
        conname AS constraint_name,
        pg_get_constraintdef(c.oid) AS constraint_definition
      FROM
        pg_constraint c
      JOIN
        pg_namespace n ON n.oid = c.connamespace
      WHERE
        n.nspname = 'public' AND c.conrelid = 'public.absensi'::regclass;
    `);
    
    console.log('\n--- Constraints in absensi table ---');
    conRes.rows.forEach(row => {
      console.log(`  - ${row.constraint_name}: ${row.constraint_definition}`);
    });
    
    // 3. Get indexes of 'absensi'
    const idxRes = await client.query(`
      SELECT
        tablename,
        indexname,
        indexdef
      FROM
        pg_indexes
      WHERE
        schemaname = 'public' AND tablename = 'absensi';
    `);
    
    console.log('\n--- Indexes in absensi table ---');
    idxRes.rows.forEach(row => {
      console.log(`  - ${row.indexname}: ${row.indexdef}`);
    });

    await client.end();
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
