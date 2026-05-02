require('dotenv').config();
const { pool } = require('./src/db');

async function run() {
  try {
    await pool.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);

      UPDATE users 
      SET email = lower(username) 
      WHERE email IS NULL;

      CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique 
      ON users(lower(email));
    `);

    console.log('SQL executed successfully');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit();
  }
}

run();
