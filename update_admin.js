const { Pool } = require('pg');
require('dotenv').config({ path: './backend/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function updateAdmin() {
  try {
    const res = await pool.query("UPDATE users SET system_role = 'admin' WHERE username = 'admin' RETURNING *");
    if (res.rows.length > 0) {
      console.log('Successfully updated user to admin:', res.rows[0]);
    } else {
      console.log('User "admin" not found.');
    }
  } catch (err) {
    console.error('Error updating user:', err);
  } finally {
    await pool.end();
  }
}

updateAdmin();
