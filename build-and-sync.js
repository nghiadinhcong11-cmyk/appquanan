const { execSync } = require('child_process');
const fs = require('fs-extra');
const path = require('path');

const ROOT = __dirname;
const FLUTTER_DIR = path.join(ROOT, 'restaurant_app');
const BACKEND_DIR = path.join(ROOT, 'backend');
const PUBLIC_DIR = path.join(BACKEND_DIR, 'public');

// Cấu hình URL API Production của bạn
const API_URL = 'https://appquanan.onrender.com/api';

async function main() {
  try {
    console.log('🚀 Bắt đầu quy trình tự động hóa...');

    // 1. Build Flutter Web
    console.log('🛠️  Đang build Flutter Web với base-href=/ ...');
    execSync(
      `flutter build web --release --base-href / --dart-define=API_BASE_URL=${API_URL}`,
      { cwd: FLUTTER_DIR, stdio: 'inherit' }
    );

    // 2. Tạo/Làm sạch thư mục public trong backend
    console.log('🧹 Đang chuẩn bị thư mục backend/public...');
    if (fs.existsSync(PUBLIC_DIR)) {
      fs.removeSync(PUBLIC_DIR);
    }
    fs.ensureDirSync(PUBLIC_DIR);

    // 3. Copy file từ build/web sang backend/public
    const buildResult = path.join(FLUTTER_DIR, 'build', 'web');
    console.log(`📂 Đang copy dữ liệu từ ${buildResult} sang ${PUBLIC_DIR}...`);
    fs.copySync(buildResult, PUBLIC_DIR);

    // 4. Kiểm tra file quan trọng
    if (fs.existsSync(path.join(PUBLIC_DIR, 'index.html'))) {
      console.log('✅ Thành công! Cấu trúc thư mục hiện tại:');
      console.log('   - backend/public/index.html');
      console.log('   - backend/public/assets/...');
    }

    console.log('\n✨ Xong! Giờ bạn có thể đẩy code lên GitHub để Render tự động deploy.');
  } catch (err) {
    console.error('❌ Lỗi:', err.message);
    process.exit(1);
  }
}

// Cài đặt thư viện bổ trợ nếu chưa có
try {
  require('fs-extra');
  main();
} catch (e) {
  console.log('📦 Đang cài đặt thư viện hỗ trợ (fs-extra)...');
  execSync('npm install fs-extra', { stdio: 'inherit' });
  main();
}
