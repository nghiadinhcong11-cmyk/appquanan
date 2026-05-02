require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error('Missing DATABASE_URL');

  const username = (process.env.ADMIN_EMAIL || process.env.ADMIN_USERNAME || '').trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  const displayName = process.env.ADMIN_DISPLAY_NAME || 'System Admin';
  if (!username || !password) {
    throw new Error('Missing ADMIN_EMAIL (or ADMIN_USERNAME) / ADMIN_PASSWORD');
  }

  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false },
  });

  try {
    const passwordHash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      `INSERT INTO users(username, email, display_name, password_hash, system_role)
       VALUES($1, $2, $3, $4, 'admin')
       ON CONFLICT (username)
       DO UPDATE SET
         email = EXCLUDED.email,
         display_name = EXCLUDED.display_name,
         password_hash = EXCLUDED.password_hash,
         system_role = 'admin'
       RETURNING id::text, username, email, display_name, system_role`,
      [username, username, displayName, passwordHash],
    );

    const user = result.rows[0];
    console.log('[seed-admin] Ready:', user);
    console.log('[seed-admin] Login username:', username);
    console.log('[seed-admin] Login password:', password);
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('[seed-admin] Failed:', err.message);
  process.exit(1);
});
