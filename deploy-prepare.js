const { execSync } = require('child_process');
const fs = require('fs-extra');
const path = require('path');

// Cấu hình đường dẫn
const ROOT_DIR = __dirname;
const FLUTTER_DIR = path.join(ROOT_DIR, 'restaurant_app');
const BACKEND_PUBLIC_DIR = path.join(ROOT_DIR, 'backend', 'public');
const API_URL = 'https://appquanan.onrender.com/api';

async function deploy() {
  try {
    console.log('🚀 Bắt đầu quy trình chuẩn bị Deploy...');

    // 1. Kiểm tra Flutter SDK
    console.log('📦 Đang kiểm tra Flutter...');
    execSync('flutter --version', { stdio: 'ignore' });

    // 2. Build Flutter Web
    console.log('🛠️ Đang build Flutter Web (Release)...');
    execSync(
      `flutter build web --release --base-href / --dart-define=API_BASE_URL=${API_URL}`,
      { cwd: FLUTTER_DIR, stdio: 'inherit' }
    );

    // 3. Chuẩn bị thư mục public trong backend
    console.log('🧹 Đang dọn dẹp thư mục backend/public...');
    if (fs.existsSync(BACKEND_PUBLIC_DIR)) {
      fs.removeSync(BACKEND_PUBLIC_DIR);
    }
    fs.ensureDirSync(BACKEND_PUBLIC_DIR);

    // 4. Copy nội dung build sang backend/public
    const buildPath = path.join(FLUTTER_DIR, 'build', 'web');
    console.log(`📂 Đang copy từ ${buildPath} sang ${BACKEND_PUBLIC_DIR}...`);
    fs.copySync(buildPath, BACKEND_PUBLIC_DIR);

    // 5. Kiểm tra file quan trọng
    if (fs.existsSync(path.join(BACKEND_PUBLIC_DIR, 'index.html'))) {
      console.log('✨ Build và Copy thành công! index.html đã sẵn sàng.');
    } else {
      throw new Error('Không tìm thấy index.html sau khi copy!');
    }

    console.log('\n✅ QUY TRÌNH HOÀN TẤT!');
    console.log('Giờ bạn chỉ cần: git add . && git commit -m "Deploy update" && git push');

  } catch (error) {
    console.error('\n❌ LỖI TRONG QUÁ TRÌNH THỰC HIỆN:');
    console.error(error.message);
    process.exit(1);
  }
}

// Cài đặt fs-extra nếu chưa có để hỗ trợ thao tác file mạnh mẽ hơn
try {
  require('fs-extra');
  deploy();
} catch (e) {
  console.log('📦 Đang cài đặt thư viện hỗ trợ (fs-extra)...');
  execSync('npm install fs-extra', { stdio: 'inherit' });
  deploy();
}
