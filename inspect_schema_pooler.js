const { Client } = require('pg');

async function main() {
  const client = new Client({
    host: '2406:da1c:61c:d600:9748:2822:db4a:f992',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: 'PindangAyam1!',
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    console.log('Connected to DB via IPv6!');
    
    // Get all tables and their columns
    const res = await client.query(`
      SELECT 
        table_name, 
        column_name, 
        data_type, 
        is_nullable
      FROM 
        information_schema.columns
      WHERE 
        table_schema = 'public'
      ORDER BY 
        table_name, 
        ordinal_position;
    `);
    
    const tables = {};
    for (const row of res.rows) {
      if (!tables[row.table_name]) {
        tables[row.table_name] = [];
      }
      tables[row.table_name].push(`${row.column_name} (${row.data_type}, nullable: ${row.is_nullable})`);
    }
    
    for (const [table, cols] of Object.entries(tables)) {
      console.log(`\nTable: ${table}`);
      cols.forEach(c => console.log(`  - ${c}`));
    }
    
    await client.end();
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
