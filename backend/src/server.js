require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const { pool } = require('./db');
const authRoutes = require('./routes/auth.routes');
const appRoutes = require('./routes/app.routes');
const publicRoutes = require('./routes/public.routes');
const privateRoutes = require('./routes/private.routes');

const app = express();

// 1. Cấu hình CORS
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-restaurant-id', 'Accept', 'X-Requested-With'],
  optionsSuccessStatus: 204
}));

app.use(express.json());

// 2. API Routes (Prefix /api)
app.use('/api/auth', authRoutes);
app.use('/api/public', publicRoutes);
app.use('/api/private', privateRoutes);
app.use('/api', appRoutes);

// 3. Serve Static Files (Flutter Web)
// __dirname là backend/src, nên ../public trỏ về backend/public
const publicPath = path.join(__dirname, '../public');
app.use(express.static(publicPath));

// 4. SPA Fallback (Quan trọng cho Flutter Web điều hướng)
app.get('*', (req, res, next) => {
  // Bỏ qua các yêu cầu API để tránh trả về index.html khi API lỗi
  if (req.path.startsWith('/api')) {
    return next();
  }
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Xử lý lỗi
app.use((err, _req, res, _next) => {
  console.error('[SERVER ERROR]', err);
  res.status(500).json({ error: 'Internal Server Error' });
});

const port = process.env.PORT || 4000;
app.listen(port, '0.0.0.0', () => {
  console.log(`\n🚀 Backend running on port ${port}`);
  console.log(`📡 API Base: http://localhost:${port}/api`);
  console.log(`🏠 Web UI: http://localhost:${port}/`);
});
