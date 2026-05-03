require('dotenv').config();
const { pool } = require('./src/db');

async function run() {
  try {
    console.log('Đang kết nối để cập nhật cấu trúc bảng tables...');
    
    // Câu lệnh thêm cột is_temporary nếu chưa có
    await pool.query(`
      ALTER TABLE tables 
      ADD COLUMN IF NOT EXISTS is_temporary BOOLEAN DEFAULT FALSE;
    `);

    console.log('✅ SQL executed successfully: Đã thêm cột is_temporary vào bảng tables.');
  } catch (err) {
    console.error('❌ Lỗi khi thực thi SQL:', err);
  } finally {
    // Đóng kết nối và thoát tiến trình
    process.exit();
  }
}

run();