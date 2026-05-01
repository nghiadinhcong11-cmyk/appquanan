const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');
const { pool } = require('./db');
const authRoutes = require('./routes/auth.routes');
const appRoutes = require('./routes/app.routes');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

async function initDb() {
  const sql = fs.readFileSync(path.join(__dirname, '..', 'sql', 'schema.sql'), 'utf8');
  await pool.query(sql);
}

app.use('/auth', authRoutes);
app.use('/', appRoutes);

const port = process.env.PORT || 4000;
initDb()
  .then(() => {
    app.listen(port, '0.0.0.0', () => {
      console.log(`Backend running at http://0.0.0.0:${port}`);
    });
  })
  .catch((e) => {
    console.error('Failed to init DB:', e);
    process.exit(1);
  });
