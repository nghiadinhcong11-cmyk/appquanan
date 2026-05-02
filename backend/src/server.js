require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const authRoutes = require('./routes/auth.routes');
const appRoutes = require('./routes/app.routes');

const path = require('path');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);
app.use('/', appRoutes);

// Serve Flutter Web static files
const publicPath = path.join(__dirname, '../public');
app.use(express.static(publicPath));

// Fallback for SPA (Single Page Application)
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/auth') || req.path === '/health' || req.path === '/bootstrap') {
    return next();
  }
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Global error handler
app.use((err, _req, res, _next) => {
  console.error('[HTTP] Unhandled route error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

process.on('unhandledRejection', (reason) => {
  console.error('[Process] Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[Process] Uncaught Exception:', err);
});

async function warmupDb() {
  if (!pool) {
    console.error('[Startup] DB pool is not available. Service will start without DB connectivity.');
    return;
  }

  try {
    await pool.query('SELECT 1');
    console.log('[Startup] Database connection check succeeded.');
  } catch (err) {
    console.error('[Startup] Database connection check failed. Service will continue running:', err);
  }
}

const port = process.env.PORT || 4000;

(async () => {
  await warmupDb();

  app.listen(port, '0.0.0.0', () => {
    console.log(`Backend running on 0.0.0.0:${port}`);
  });
})();
