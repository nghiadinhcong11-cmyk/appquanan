const { Pool } = require('pg');

const databaseUrl = process.env.DATABASE_URL;

let pool = null;

if (!databaseUrl) {
  console.error('[DB] Missing DATABASE_URL environment variable. Database features will be unavailable.');
} else {
  try {
    pool = new Pool({
      connectionString: databaseUrl,
      ssl: { rejectUnauthorized: false },
    });

    pool.on('error', (err) => {
      console.error('[DB] Unexpected pool error:', err);
    });
  } catch (err) {
    console.error('[DB] Failed to initialize pool:', err);
    pool = null;
  }
}

module.exports = { pool };
