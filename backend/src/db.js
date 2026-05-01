const dotenv = require('dotenv');
const { Pool } = require('pg');

dotenv.config();

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) throw new Error('Missing DATABASE_URL');

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.PG_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

module.exports = { pool };
