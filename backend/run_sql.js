require('dotenv').config();
const { pool } = require('./src/db');

async function run() {
  try {
    console.log('--- ĐANG KẾT NỐI VÀ CẬP NHẬT DATABASE ONLINE ---');
    
    // 1. Cập nhật bảng tables (Thêm cột và reset status)
    await pool.query(`
      ALTER TABLE tables 
      ADD COLUMN IF NOT EXISTS is_temporary BOOLEAN DEFAULT FALSE;

      UPDATE tables SET status = 'empty' WHERE status IS NULL;
    `);
    console.log('✅ Bảng tables: Cập nhật thành công.');

    // 2. Cập nhật bảng order_items
    await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='order_items' AND column_name='status') THEN
          ALTER TABLE order_items ADD COLUMN status VARCHAR(50) DEFAULT 'pending';
        END IF;
      END $$;

      -- Đồng bộ status theo bill_id
      UPDATE order_items SET status = 'paid' WHERE bill_id IS NOT NULL AND (status IS NULL OR status != 'paid');
      UPDATE order_items SET status = 'pending' WHERE bill_id IS NULL AND status IS NULL;
    `);
    console.log('✅ Bảng order_items: Đồng bộ trạng thái thành công.');

    console.log('\n🚀 TẤT CẢ ĐÃ SẴN SÀNG! Hãy push code và restart Render.');
  } catch (err) {
    console.error('❌ LỖI THỰC THI:', err.message);
  } finally {
    process.exit();
  }
}

run();
