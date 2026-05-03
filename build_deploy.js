const { execSync } = require('child_process');
const fs = require('fs-extra');
const path = require('path');

const ROOT = __dirname;
const FLUTTER_DIR = path.join(ROOT, 'restaurant_app');
const BACKEND_DIR = path.join(ROOT, 'backend');
const PUBLIC_DIR = path.join(BACKEND_DIR, 'public');

// URL API thực tế trên Render của bạn
const API_URL = 'https://appquanan.onrender.com/api';

async function build() {
  try {
    console.log('🚀 Bắt đầu quy trình đóng gói ứng dụng...');

    // 1. Build Flutter Web
    console.log('🛠️  Đang build Flutter Web (Release)...');
    execSync(
      `flutter build web --release --base-href / --dart-define=API_BASE_URL=${API_URL}`,
      { cwd: FLUTTER_DIR, stdio: 'inherit' }
    );

    // 2. Chuẩn bị thư mục public
    console.log('🧹 Đang dọn dẹp thư mục backend/public...');
    if (fs.existsSync(PUBLIC_DIR)) {
      fs.removeSync(PUBLIC_DIR);
    }
    fs.ensureDirSync(PUBLIC_DIR);

    // 3. Copy file build sang backend/public
    const buildPath = path.join(FLUTTER_DIR, 'build', 'web');
    console.log(`📂 Đang copy từ ${buildPath} sang ${PUBLIC_DIR}...`);
    fs.copySync(buildPath, PUBLIC_DIR);

    console.log('✅ THÀNH CÔNG! Cấu trúc đã sẵn sàng:');
    console.log(`   - ${path.join(PUBLIC_DIR, 'index.html')}`);

  } catch (err) {
    console.error('❌ LỖI:', err.message);
    process.exit(1);
  }
}

// Cài đặt fs-extra nếu chưa có
try {
  require('fs-extra');
  build();
} catch (e) {
  console.log('📦 Đang cài đặt thư viện hỗ trợ (fs-extra)...');
  execSync('npm install fs-extra', { stdio: 'inherit' });
  build();
}
