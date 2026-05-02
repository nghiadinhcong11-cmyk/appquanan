require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

async function main() {
  const databaseUrl = process.env.DATABASE_URL;

  if (!databaseUrl) {
    console.error('[migrate] Missing DATABASE_URL environment variable');
    process.exit(1);
  }

  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false },
  });

  try {
    const schemaPath = path.join(__dirname, 'sql', 'schema.sql');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');

    await pool.query('BEGIN');
    await pool.query(schemaSql);
    await pool.query('COMMIT');

    console.log('[migrate] Schema migration completed successfully.');
    process.exit(0);
  } catch (error) {
    try {
      await pool.query('ROLLBACK');
    } catch (_) {}

    console.error('[migrate] Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
