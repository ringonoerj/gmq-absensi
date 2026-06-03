const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:PindangAyam1!@db.dqrymuvfkxtzzltlqzhw.supabase.co:5432/postgres',
});

async function main() {
  await client.connect();
  console.log('Connected to database.');
  
  try {
    const res = await client.query('SELECT id, email, encrypted_password, role, created_at FROM auth.users;');
    console.log('Auth Users:');
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error('Error querying auth.users:', err);
  } finally {
    await client.end();
  }
}

main();
