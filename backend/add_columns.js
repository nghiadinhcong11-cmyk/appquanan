require('dotenv').config();
const { Pool } = require('pg');

async function run() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });

  try {
    console.log('Adding columns to tables...');
    await pool.query(`
      ALTER TABLE tables
      ADD COLUMN IF NOT EXISTS floor VARCHAR(50) DEFAULT 'Tầng 1',
      ADD COLUMN IF NOT EXISTS is_temporary BOOLEAN DEFAULT false;
    `);
    console.log('Columns added successfully.');
  } catch (err) {
    console.error('Error adding columns:', err);
  } finally {
    await pool.end();
  }
}

run();
