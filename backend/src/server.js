require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const authRoutes = require('./routes/auth.routes');
const appRoutes = require('./routes/app.routes');
const publicRoutes = require('./routes/public.routes');
const privateRoutes = require('./routes/private.routes');

const path = require('path');

const app = express();

// 1. Cấu hình CORS tối ưu cho Web
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-restaurant-id', 'Accept', 'X-Requested-With'],
  optionsSuccessStatus: 204
}));

app.use(express.json());

// 2. Định tuyến API với prefix /api để tránh xung đột với Flutter Web routes
app.use('/api/auth', authRoutes);
app.use('/api/public', publicRoutes);
app.use('/api/private', privateRoutes);
app.use('/api', appRoutes);

// 3. Phục vụ Flutter Web static files
const publicPath = path.join(__dirname, '../public');
app.use(express.static(publicPath));

// 4. SPA Fallback: Nếu không phải yêu cầu API, trả về index.html của Flutter
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api')) {
    return next(); // Để API trả về 404 nếu không tìm thấy, không trả về index.html
  }
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Xử lý lỗi toàn cục
app.use((err, _req, res, _next) => {
  console.error('[SERVER ERROR]', err);
  res.status(500).json({ error: 'Lỗi hệ thống: ' + err.message });
});

const port = process.env.PORT || 4000;
app.listen(port, '0.0.0.0', () => {
  console.log(`\n🚀 Backend running on port ${port}`);
  console.log(`📡 API Base URL: http://localhost:${port}/api`);
  console.log(`🔒 JWT_SECRET: ${process.env.JWT_SECRET ? 'OK' : 'MISSING'}\n`);
});
